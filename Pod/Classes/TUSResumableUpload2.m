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
#import "TUSFileReader.h"
#import "TUSUploadStore.h"
#import "TUSSession.h"

#define HTTP_PATCH @"PATCH"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_OFFSET @"Upload-Offset"
#define HTTP_UPLOAD_LENGTH  @"Upload-Length"
#define HTTP_TUS @"Tus-Resumable"
#define HTTP_TUS_VERSION @"1.0.0"

#define HTTP_LOCATION @"Location"
#define REQUEST_TIMEOUT 30



@interface TUSResumableUpload2 ()

// Readwrite versions of properties in the header
@property (readwrite, strong) NSString *id;
@property (readwrite) BOOL idle;
@property (readwrite) TUSUploadState state;

// Internal state
@property (nonatomic, weak) id<TUSResumableUpload2Delegate> delegate; // Current upload offset
@property (nonatomic) NSUInteger offset; // Current upload offset
@property (nonatomic, strong) NSURL *uploadUrl; // Target URL for file
@property (nonatomic, strong) NSDictionary *uploadHeaders;
@property (nonatomic, strong) NSDictionary <NSString *, NSString *> *metadata;
@property (nonatomic, strong) TUSData *data;

#pragma mark private method headers

/**
 Perform the TUS actions specified and return the Task
 */
- (NSURLSessionTask *) checkFile:(NSURLSession *)session;
- (NSURLSessionTask *) createFile:(NSURLSession *)session;
- (NSURLSessionTask *) uploadFile:(NSURLSession *)session;

/**
 Update the state of the upload from the server response headers
 */
- (void) updateStateFromHeaders:(NSDictionary*)headers;

/**
 Serialize this resumable upload for saving
 */
- (NSDictionary *) serializeUpload;


/**
 Save this TUSResumableUpload2 to the store for later recovery
 */
-(void)saveToStore;

/**
 Generate a UUID that will be unique for the specified datastore
 */
-(NSString *)generateUUIDForStore:(TUSUploadStore *)store;


@end

@implementation TUSResumableUpload2

- (instancetype _Nullable)initWithFile:(NSURL * _Nonnull)fileUrl
                              delegate:(id <TUSResumableUpload2Delegate> _Nonnull)delegate
                         uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata

{
    self = [super init];
    
    if (self) {
        _delegate = delegate;
        _uploadHeaders = headers;
        _state = CheckingFile;
        _idle = YES;
        _id = [self generateUUIDForStore:delegate.store];
        
        // TODO: Set up file NSData
        
        // Set up metadata with filename if there is one
        NSMutableDictionary *uploadMetadata = [NSMutableDictionary new];
        if (fileUrl.isFileURL) {
            uploadMetadata[@"filename"] = fileUrl.lastPathComponent;
        }
        
        if (metadata){
            [uploadMetadata addEntriesFromDictionary:metadata];
        }
        _metadata = uploadMetadata;
        
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

- (BOOL)complete
{
    return self.state == Complete;
}

- (NSURLSessionTask *) makeNextCallWithSession:(NSURLSession *)session
{
    // If the process is idle, need to begin at current state
    if (self.idle) {
        switch (self.state) {
            case CreatingFile:
                return [self createFile:session];
            case CheckingFile:
                return [self checkFile:session];
            case UploadingFile:
                return [self uploadFile:session];
            case Complete:
            default:
                return nil;
        }
    }
    return nil;
}

- (NSURLSessionTask *) createFile:(NSURLSession *) session
{
    self.state = CreatingFile;
    
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
    
    return [self.delegate.session dataTaskWithRequest:request];
}

- (NSURLSessionTask *) checkFile:(NSURLSession *) session
{
    self.state = CheckingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Create a download task for the empty post (file to be deleted later)
    // TODO: determine if an NSURLSessionDataTask can run while your app is in the background (docs are unclear)
    return [session downloadTaskWithRequest:request];
}

- (NSURLSessionTask *) uploadFile:(NSURLSession *)session
{
    self.state = UploadingFile;
    self.failed = NO;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", (long long)self.offset] forKey:HTTP_OFFSET];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    [mutableHeader setObject:@"application/offset+octet-stream" forKey:@"Content-Type"];

    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    TUSLog(@"Resuming upload at %@ for fingerprint %@ from offset %lld",
           [self url], [self fingerprint], (long long)self.offset);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PATCH];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Add the uploadTask (request) to the session
    NSError *error = nil;
    return [session uploadTaskWithRequest:request fromFile:[self.fileReader getFileFromOffset:self.offset error:&error]];
}


#pragma mark - Private Methods
- (long long) length {
    return self.fileReader.length;
}

#pragma mark - URLSession delegate methods

- (void) task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSHTTPURLResponse *httpResponse = task.response;

    NSLog(@"Response Code %li, Sent %li, Expected %li, State %li", [httpResponse statusCode], totalBytesSent, totalBytesExpectedToSend, task.state);


}

-(void) task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (self.failureBlock) {
        self.failureBlock(error);
    }
    
    NSHTTPURLResponse *httpResponse = task.response;
    NSLog(@"%li", [httpResponse statusCode]);
    
        
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch(self.state) {
        case CheckingFile: {
            if (httpResponse == nil){
                TUSLog(@"No response during attempt to check file, retrying");
                break;
            } else if ([httpResponse statusCode] < 200 && [httpResponse statusCode] > 204) {
                TUSLog(@"Server responded to file check with %ld. Restarting upload",
                       (long)httpResponse.statusCode);
                //TODO: Error callback
                //TODO: Deal with gateway timeouts by going back to CheckingFile vs. creating
                self.state = CreatingFile;
                break;
            }
            [self updateStateFromHeaders:headers];
            break;
        }
        case CreatingFile: {
            if ([httpResponse statusCode] != 200 && [httpResponse statusCode] != 201) {
                TUSLog(@"Server responded to create request with %ld status code.",
                       (long)httpResponse.statusCode);
                self.failed = YES;
                //TODO: Handle error callbacks (lock retrying)
                break;
            }
            
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            self.url = [NSURL URLWithString:location];
            
            TUSLog(@"Created resumable upload at %@ for fingerprint %@", [self url], [self fingerprint]);
            
            self.state = UploadingFile;
            break;
        }
        case UploadingFile: {
            if (httpResponse == nil){
                TUSLog(@"No response during attempt to upload, so checking file");
                self.state = CheckingFile; // No response, so check file again as some bytes may have been received
                break;
            } else if ([httpResponse statusCode] != 204) {
                self.failed = YES;
                self.state = CheckingFile;
                //TODO: Handle error callbacks (problem on server)
                TUSLog(@"Server returned unexpected status code to upload - %ld", (long)httpResponse.statusCode);
                break;
            }
            [self updateStateFromHeaders:headers];
            break;
        }
        case Complete: {
            TUSLog(@"Unexpected response from server in complete state for upload at %@ for fingerprint %@", self.url, self.fingerprint);
            break;
        }
        default:
            break;
    }

    // Upload is now idle
    self.idle = YES;
    
    // Save to the store
    [self saveToStore:self.uploadStore];
}

-(void) downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    // Delete the downloaded response
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:location error:&error];
}

//-(void) task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
//{
//    switch([self state]) {
//        case UploadingFile:
//            if (self.progressBlock) {
//                self.progressBlock((NSUInteger)totalBytesSent + self.offset, self.fileReader.length);
//            }
//            break;
//        default:
//            break;
//    }
//}

//-(void) dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
//    
//    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//    NSDictionary *headers = [httpResponse allHeaderFields];
//    
//    switch(self.state) {
//        case CheckingFile: {
//            if ([httpResponse statusCode] != 200 && [httpResponse statusCode] != 201) {
//                TUSLog(@"Server responded to file check with %ld. Restarting upload",
//                       (long)httpResponse.statusCode);
//                //TODO: Error callback
//                //TODO: Deal with gateway timeouts by going back to CheckingFile vs. creating
//                self.state = CreatingFile;
//                break;
//            }
//            [self updateStateFromHeaders:headers];
//            break;
//        }
//        case CreatingFile: {
//            if ([httpResponse statusCode] != 200 && [httpResponse statusCode] != 201) {
//                TUSLog(@"Server responded to create request with %ld status code.",
//                       (long)httpResponse.statusCode);
//                self.failed = YES;
//                //TODO: Handle error callbacks (lock retrying)
//                break;
//            }
//            
//            NSString *location = [headers valueForKey:HTTP_LOCATION];
//            self.url = [NSURL URLWithString:location];
//            
//            TUSLog(@"Created resumable upload at %@ for fingerprint %@", [self url], [self fingerprint]);
//            
//            self.state = UploadingFile;
//            break;
//        }
//        case UploadingFile: {
//            if ([httpResponse statusCode] != 204) {
//                self.failed = YES;
//                self.state = CheckingFile;
//                //TODO: Handle error callbacks (problem on server)
//                TUSLog(@"Server returned unexpected status code to upload - %ld", (long)httpResponse.statusCode);
//                break;
//            }
//            [self updateStateFromHeaders:headers];
//            break;
//        }
//        case Complete: {
//            TUSLog(@"Unexpected response from server in complete state for upload at %@ for fingerprint %@", self.url, self.fingerprint);
//            break;
//        }
//        default:
//            break;
//    }
//    
//    // Upload is now idle
//    self.idle = YES;
//    
//    // Save to the store
//    [self saveToStore:self.uploadStore];
//    
//    completionHandler(NSURLSessionResponseAllow);
//}

/**
 Uses the offset from the provided headers to update the state of the upload - used by both check (HEAD) and upload (PATCH) response logic.
 */
-(void)updateStateFromHeaders:(NSDictionary*)headers
{
    NSString *rangeHeader = [headers valueForKey:HTTP_OFFSET];
    if (rangeHeader) {
        long long serverOffset = [rangeHeader longLongValue];
        if (serverOffset >= [self length]) {
            //TODO: Should we verify the file?
            TUSLog(@"Upload complete at %@ for fingerprint %@", [self url], [self fingerprint]);
    
            if (self.resultBlock) {
                self.resultBlock(self.url);
            }
            self.state = Complete;
            [self.fileReader close];
            return;
        } else {
            self.offset = (NSUInteger)serverOffset;
            self.state = UploadingFile;
        }
        TUSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
               [self url], [self fingerprint], (long long)self.offset, rangeHeader);
        return;
    }
    else {
        TUSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
        // We didn't get an offset header, so we need to run the check again
        self.state = CheckingFile;
        return;
    }
}

#pragma mark Persistence functions
+(instancetype)loadUploadWithId:(NSString *)uploadId fromStore:(TUSUploadStore *)store
{
    NSDictionary *savedData = [store loadDictionaryForUpload:uploadId];
    
    // If there is no data associated with the upload ID
    if (savedData == nil) {
        return nil;
    }
    
    NSURL *endpoint = [savedData objectForKey:@"endpoint"];
    NSURL *uploadUrl = [savedData objectForKey:@"uploadUrl"]; // Could be NSNull
    NSURL *sourceUrl = [savedData objectForKey:@"sourceUrl"];
    BOOL idle = [savedData[@"idle"] boolValue];
    BOOL failureStatus = [savedData[@"failed"] boolValue];
    NSDictionary *headers = [savedData objectForKey:@"headers"];
    NSDictionary <NSString *, NSString *> *metadata = [savedData objectForKey:@"uploadMetadata"];
    NSDictionary *savedFileReader = savedData[@"fileReader"];
    TUSFileReader *fileReader = [TUSFileReader deserializeFromDictionary:savedFileReader];
    TUSUploadState state = [[savedData objectForKey:@"state"] integerValue];
    
    return [[TUSResumableUpload2 alloc] initWithUploadId:uploadId
                                            endpoint:endpoint
                                           uploadUrl:uploadUrl
                                           sourceURL:sourceUrl
                                          idleStatus:idle
                                           failureStatus:failureStatus
                                             headers:headers
                                                metadata:metadata
                                              fileReader:fileReader
                                               state:state
                                               store:store];
}

-(NSDictionary *) serializeObject
{
    NSDictionary *uploadData = @{@"uploadId": self.id,
                                 @"endpoint": self.endpoint,
                                 @"uploadUrl": self.url ?: [NSNull null],
                                 @"sourceUrl": self.fingerprint,
                                 @"idle": @(self.idle),
                                 @"failed": @(self.failed),
                                 @"uploadMetadata": self.metadata,
                                 @"headers": self.uploadHeaders,
                                 @"fileReader": [self.fileReader serialize],
                                 @"state": @(self.state)};

    return uploadData;
}



-(void)saveToStore:(TUSUploadStore *)store
{
    [store saveDictionaryForUpload:self.id dictionary:[self serializeObject]];
}

@end
