//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions for background uploading by Findyr.
//  Copyright (c) 2016 Findyr. All rights reserved.

#import "TUSKit.h"
#import "TUSData.h"

#import "TUSResumableUpload2+Private.h"
#import "TUSUploadStore.h"
#import "TUSSession.h"
#import "TUSFileData.h"

#define HTTP_PATCH @"PATCH"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_OFFSET @"Upload-Offset"
#define HTTP_UPLOAD_LENGTH  @"Upload-Length"
#define HTTP_TUS @"Tus-Resumable"
#define HTTP_TUS_VERSION @"1.0.0"

#define HTTP_LOCATION @"Location"
#define REQUEST_TIMEOUT 30

// Keys used in serialization
#define STORE_KEY_ID @"id"
#define STORE_KEY_UPLOAD_URL @"uploadUrl"
#define STORE_KEY_DELEGATE_ENDPOINT @"delegateEndpoint" // For checking that the delegate matches
#define STORE_KEY_FILE_URL @"fileUrl"
#define STORE_KEY_UPLOAD_HEADERS @"uploadHeaders"
#define STORE_KEY_METADATA @"metadata"
#define STORE_KEY_LENGTH @"uploadLength"
#define STORE_KEY_LAST_STATE @"lastState"


typedef void(^NSURLSessionTaskCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@interface TUSResumableUpload2 ()

// Readwrite versions of properties in the header
@property (readwrite, strong) NSString *uploadId;
@property (readwrite) BOOL idle;
@property (readwrite) TUSSessionUploadState state;

// Internal state
@property (nonatomic) BOOL cancelled;
@property (nonatomic, weak) id<TUSResumableUpload2Delegate> delegate; // Current upload offset
@property (nonatomic) long long offset; // Current upload offset
@property (nonatomic, strong) NSURL *uploadUrl; // Target URL for file
@property (nonatomic, strong) NSDictionary *uploadHeaders;
@property (nonatomic, strong) NSDictionary <NSString *, NSString *> *metadata;
@property (nonatomic, strong) TUSData *data;
@property (nonatomic, strong) NSURLSessionTask *currentTask; // Nonatomic because we know we will assign it, then start the thread that will remove it.
@property (nonatomic, strong) NSURL *fileUrl; // File URL for saving if we created our own TUSData
@property (readonly) long long length;

#pragma mark private method headers

/**
 Perform the TUS actions specified and return the Task
 */
- (BOOL) checkFile;
- (BOOL) createFile;
- (BOOL) uploadFile;

/**
 Update the state of the upload from the server response headers
 */
- (void) updateStateFromHeaders:(NSDictionary*)headers;

/**
 Serialize this resumable upload for reloading if the app is closed.  Note that the state will not necessarily be the same on restoring the upload.
 */
- (NSDictionary *) serialize;

/**
 Make the next call on this upload
 */
- (BOOL) continueUpload;

/**
 Save this TUSResumableUpload2 to the store for later recovery
 */
-(void)saveToStore;

/**
 Generate a UUID that will be unique for the specified datastore
 */
-(NSString *)generateUUIDForStore:(TUSUploadStore *)store;

/**
 Private designated initializer
 No parameters are modified or checked in any way except for state.
 */
- (instancetype _Nullable) initWithUploadId:(NSString *)uploadId
                                       file:(NSURL* _Nullable)fileUrl
                                   delegate:(id<TUSResumableUpload2Delegate> _Nonnull)delegate
                              uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              finalMetadata:(NSDictionary <NSString *, NSString *>* _Nonnull)metadata
                                      state:(TUSSessionUploadState)state
                                  uploadUrl:(NSURL * _Nullable)uploadUrl;

@end

@implementation TUSResumableUpload2

- (instancetype _Nullable)initWithFile:(NSURL * _Nonnull)fileUrl
                              delegate:(id <TUSResumableUpload2Delegate> _Nonnull)delegate
                         uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata

{
    if (!fileUrl.fileURL){
        NSLog(@"URL provided to TUSResumableUpload2 is not a file URL: %@", fileUrl);
        return nil;
    }
    
    // Set up metadata with filename
    NSMutableDictionary *uploadMetadata = [NSMutableDictionary new];
    uploadMetadata[@"filename"] = fileUrl.filePathURL.lastPathComponent;
    if (metadata){
        [uploadMetadata addEntriesFromDictionary:metadata];
    }
    
    return [self initWithUploadId:[self generateUUIDForStore:delegate.store]
                             file:fileUrl
                         delegate:delegate
                    uploadHeaders:headers
                    finalMetadata:uploadMetadata
                            state:TUSSessionUploadStateCreatingFile
                        uploadUrl:nil];
    
}


/**
 Private designated initializer
 No parameters are modified or checked in any way except for state.
 */
- (instancetype _Nullable) initWithUploadId:(NSString *)uploadId
                                       file:(NSURL* _Nullable)fileUrl
                                   delegate:(id<TUSResumableUpload2Delegate> _Nonnull)delegate
                              uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              finalMetadata:(NSDictionary <NSString *, NSString *>* _Nonnull)metadata
                                      state:(TUSSessionUploadState)state
                                  uploadUrl:(NSURL * _Nullable)uploadUrl
{
    self = [super init];
    if (self) {
        _uploadId = uploadId;
        _fileUrl = fileUrl;
        _delegate = delegate;
        _uploadHeaders = headers;
        _metadata = metadata;
        _state = state;
        _uploadUrl = uploadUrl;
        _idle = YES;
        
        if (_state != TUSSessionUploadStateComplete){
            _data = [[TUSFileData alloc] initWithFileURL:fileUrl];
            if (!_data){
                NSLog(@"Error creating TUSFileData object with url %@", fileUrl);
                return nil;
            }
        }
        
        [self saveToStore];
    }
    return self;
}


+ (NSString *)generateUUIDForStore:(TUSUploadStore *)store
{
    while(1) {
        NSUUID *uuid = [[NSUUID alloc] init];
        if(![store containsUploadId:uuid.UUIDString])
            return uuid.UUIDString;
    }
}

-(BOOL)cancel
{
    self.cancelled = YES;
    if (self.currentTask){
        [self.currentTask cancel];
    }
    [self.data close];
}

- (BOOL)resume
{
    self.cancelled = NO; // Un-cancel
    return [self continueUpload];
}

-(BOOL)continueUpload
{
    // If the process is idle, need to begin at current state
    if (self.idle && !self.cancelled) {
        switch (self.state) {
            case TUSSessionUploadStateCreatingFile:
                return [self createFile];
            case TUSSessionUploadStateCheckingFile:
                return [self checkFile];
            case TUSSessionUploadStateUploadingFile:
                return [self uploadFile];
            case TUSSessionUploadStateComplete:
            default:
                return NO;
        }
    }
    return NO;
}

- (BOOL)createFile
{
    self.state = TUSSessionUploadStateCreatingFile;
    
    long long size = self.data.length;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    
    // Upload-Metadata is a custom formatted string
    NSMutableArray <NSString *> *formattedMetadata = [NSMutableArray new];
    for (NSString *entry in self.metadata) {
        NSMutableString *formattedEntry = [[NSMutableString alloc] initWithString:entry];
        [formattedEntry appendString:@" "];
        
        NSData *plainData = [self.metadata[entry] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *base64String = [plainData base64EncodedStringWithOptions:0];
        [formattedEntry appendString:base64String];
        [formattedMetadata addObject:formattedEntry];
    }
    [mutableHeader setObject:[formattedMetadata componentsJoinedByString:@","] forKey:@"Upload-Metadata"];
    
    
    // Add custom headers after the filename, as the upload-metadata may be customized
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    
    // Set the version & length last as they are determined by the uploader
    [mutableHeader setObject:[NSString stringWithFormat:@"%ll", size] forKey:HTTP_UPLOAD_LENGTH];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.delegate.createUploadURL
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Create a download task for the empty post (file to be deleted later)
    // TODO: determine if an NSURLSessionDataTask can run while your app is in the background (docs are unclear)
    
    __weak TUSResumableUpload2 * weakself = self;
    
    self.currentTask = [self.delegate.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (weakself.currentTask){ // Should only be false if self has been destroyed, but we need to account for that because of the removeTask call.
            [weakself.delegate removeTask:weakself.currentTask];
            weakself.currentTask = nil;
        }
        NSHTTPURLResponse * httpResponse;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        if (error != nil || httpResponse == nil){
            TUSLog(@"Error or no response during attempt to create file, retrying");
        } else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 204){
            TUSLog(@"Server responded to create file with %ld. Trying again",
                   (long)httpResponse.statusCode);
        } else {
            // Got a valid status code, so update url
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            self.uploadUrl = [NSURL URLWithString:location];
            if (self.uploadUrl) {
                // If we got a valid URL, set the new state to uploading.  Otherwise, will try creating again.k
                TUSLog(@"Created resumable upload at %@ for id %@", self.uploadUrl, self.uploadId);
                self.state = TUSSessionUploadStateUploadingFile;
            }
        }
        //TODO: Thread safety?
        weakself.idle = YES;
        [self saveToStore]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        [weakself continueUpload]; // Continue upload, not resume, because we do not want to continue if cancelled.
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}

- (BOOL) checkFile
{
    self.state = TUSSessionUploadStateCheckingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.uploadUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    __weak TUSResumableUpload2 * weakself = self;
    
    self.currentTask = [self.delegate.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (weakself.currentTask){ // Should only be false if self has been destroyed, but we need to account for that because of the removeTask call.
            [weakself.delegate removeTask:weakself.currentTask];
            weakself.currentTask = nil;
        }
        NSHTTPURLResponse * httpResponse;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        if (error != nil || httpResponse == nil){
            TUSLog(@"Error or no response during attempt to check file, retrying");
        } else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 204){
            TUSLog(@"Server responded to file check with %ld. Creating file",
                   (long)httpResponse.statusCode);
            //TODO: Deal with gateway timeouts and server locks by going back to CheckingFile vs. creating
            self.state = TUSSessionUploadStateCreatingFile;
        } else {
            // Got a valid status code, so update state and continue upload.
            [weakself updateStateFromHeaders:headers];
        }
        weakself.idle = YES;
        [self saveToStore]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        
        //TODO: Dispatch on new thread
        [weakself continueUpload]; // Continue upload, not resume, because we do not want to continue if cancelled.
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}

- (BOOL)uploadFile
{
    self.state = TUSSessionUploadStateUploadingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", self.offset] forKey:HTTP_OFFSET];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    [mutableHeader setObject:@"application/offset+octet-stream" forKey:@"Content-Type"];

    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    TUSLog(@"Resuming upload to %@ with id %@ from offset %lld",
           self.uploadUrl, self.uploadId, self.offset);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.uploadUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PATCH];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    [self.data setOffset:self.offset]; // Advance the offset of data to the expected value
    [request setHTTPBodyStream:self.data];
    
    
    __weak TUSResumableUpload2 * weakself = self;
    
    self.currentTask = [self.delegate.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (weakself.currentTask){ // Should only be false if self has been destroyed, but we need to account for that because of the removeTask call.
            [weakself.delegate removeTask:weakself.currentTask];
            weakself.currentTask = nil;
        }
        NSHTTPURLResponse * httpResponse;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        if (error != nil){
            TUSLog(@"Error during attempt to upload, checking state");
            weakself.state = TUSSessionUploadStateCheckingFile;
        } else if (httpResponse == nil || httpResponse.statusCode != 204){
            TUSLog(@"No response or invalid status code during attempt to upload, checking state");
            weakself.state = TUSSessionUploadStateCheckingFile;
        } else {
            [weakself updateStateFromHeaders:headers];
        }
        weakself.idle = YES;
        [self saveToStore]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        [weakself continueUpload]; // Continue upload, not resume, because we do not want to continue if cancelled.
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}


#pragma mark - Property Getters and Setters
- (long long) length {
    return self.data.length;
}

- (BOOL)complete
{
    return self.state == TUSSessionUploadStateComplete;
}

#pragma mark NSURLSessionTask Callback


/**
 Uses the offset from the provided headers to update the state of the upload - used by both check (HEAD) and upload (PATCH) response logic.
 */
-(void)updateStateFromHeaders:(NSDictionary*)headers
{
    NSString *rangeHeader = [headers valueForKey:HTTP_OFFSET];
    if (rangeHeader) {
        long long serverOffset = [rangeHeader longLongValue];
        if (serverOffset >= self.length) {
            TUSLog(@"Upload complete at %@ for id %@", self.uploadUrl, self.uploadId);
            self.state = TUSSessionUploadStateComplete;
            //TODO: Close file/data
        } else {
            TUSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
                   self.uploadUrl, self.uploadId, serverOffset, rangeHeader);
            self.offset = serverOffset;
            self.state = TUSSessionUploadStateUploadingFile;
        }
    } else {
        TUSLog(@"No header received during request for %@, so checking file", self.uploadUrl);
        // We didn't get an offset header, so we need to run the check again
        self.state = TUSSessionUploadStateCheckingFile;
    }
}

#pragma mark Persistence functions



-(NSDictionary *) serialize
{
    /*
     // Readwrite versions of properties in the header
     @property (readwrite, strong) NSString *id;

     */
    
    NSObject *fileUrlData = [NSNull null];
    if (self.fileUrl){
        NSError *error;
        NSData *bookmarkData = [self.fileUrl bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        if (error != nil){
            NSLog(@"Error creating bookmark data for URL %@", error);
        } else {
            fileUrlData = bookmarkData;
        }
    }
    
    return @{STORE_KEY_ID: self.uploadId,
             STORE_KEY_DELEGATE_ENDPOINT: self.delegate.createUploadURL.absoluteString,
             STORE_KEY_UPLOAD_URL:  self.state == TUSSessionUploadStateCreatingFile? [NSNull null] : self.uploadUrl.absoluteString, //If we are creating the file, there is no upload URL
             STORE_KEY_LENGTH: @(self.length),
             STORE_KEY_LAST_STATE: @(self.state),
             STORE_KEY_METADATA: self.metadata,
             STORE_KEY_UPLOAD_HEADERS: self.uploadHeaders,
             STORE_KEY_FILE_URL: fileUrlData};
    
}



+(instancetype)loadUploadWithId:(NSString *)uploadId delegate:(id<TUSResumableUpload2Delegate> _Nonnull)delegate
{
    NSDictionary *savedData = [delegate.store loadDictionaryForUpload:uploadId];
    
    // If there is no data associated with the upload ID
    if (savedData == nil) {
        return nil;
    } else if (![savedData[STORE_KEY_ID] isEqualToString:uploadId]){ // Sanity check
        NSLog(@"ID in stored dictionary for %@ does not match (%@)", uploadId, savedData[STORE_KEY_ID]);
        return nil;
    }
    
    NSURL * savedDelegateEndpoint = [NSURL URLWithString:savedData[STORE_KEY_DELEGATE_ENDPOINT]];
    if (![savedDelegateEndpoint isEqual:delegate.createUploadURL.absoluteString]){ // Check saved delegate endpoint
        NSLog(@"Delegate URL in stored dictionary for %@ (%@) does not match the one in the passed-in delegate %@", uploadId, savedDelegateEndpoint, delegate.createUploadURL);
        return nil;
    }
    
    // Get parameters
    //UploadID
    NSNumber *expectedLength = savedData[STORE_KEY_LENGTH];
    NSNumber *stateObj = savedData[STORE_KEY_LAST_STATE];
    TUSSessionUploadState state = stateObj.unsignedIntegerValue;
    NSDictionary *metadata = savedData[STORE_KEY_METADATA];
    NSDictionary *headers = savedData[STORE_KEY_UPLOAD_HEADERS];
    NSDictionary *uploadUrl = [NSURL URLWithString:savedData[STORE_KEY_UPLOAD_URL]];
    NSURL *fileUrl = nil;
    if(savedData[STORE_KEY_FILE_URL] != [NSNull null]){
        NSError *error;
        fileUrl = [NSURL URLByResolvingBookmarkData:savedData[STORE_KEY_FILE_URL] options:0 relativeToURL:nil bookmarkDataIsStale:nil error:&error];
        if (error != nil){ // Assuming fileUrl must be non-nil if there is no error
            NSLog(@"Error loading file URL from stored data for upload %@", uploadId);
            return nil;
        }
        // Check file length
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileUrl.filePathURL error:&error];
        if (error != nil){
            NSLog(@"Error loading details for file for saved at %@ when restoring upload %@", fileUrl, uploadId);
            return nil;
        }
        NSNumber *fileSize = fileAttributes[NSFileSize];
        if (fileSize.unsignedLongLongValue != expectedLength.unsignedLongLongValue){
            NSLog(@"Expected file size (%ulld) for saved upload %@ does not match actual file size (%ulld)", fileSize.unsignedLongLongValue, uploadId, expectedLength.unsignedLongLongValue);
            return nil;
        }
    } else if (state != TUSSessionUploadStateComplete) { // If we do not have a file url and the upload isn't complete, then we were reloading using the wrong method.
        NSLog(@"Attempt to reload non-file upload using file-based upload restore method");
        //TODO: Implement code to resume a non-file-based upload
        return nil;
    }
    
    // If the upload was previously uploading, we need to do a check before we can continue.
    if (state == TUSSessionUploadStateUploadingFile){
        state = TUSSessionUploadStateCheckingFile;
    }
    
    return [[self alloc] initWithUploadId:uploadId
                                     file:fileUrl
                                 delegate:delegate
                            uploadHeaders:headers
                            finalMetadata:metadata
                                    state:state
                                uploadUrl:uploadUrl];
}




-(void)saveToStore:(TUSUploadStore *)store
{
    [store saveDictionaryForUpload:self.uploadId dictionary:[self serialize]];
}

@end
