//
//  TUSResumableUpload.m
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr
//
//  Additions and changes for Transloadit by Mark R Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson & Transloadit. All rights reserved.

#import "TUSKit.h"
#import "TUSErrors.h"
#import "TUSData.h"

#import "TUSResumableUpload+Private.h"
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
// Delay time in seconds between retries
#define DELAY_TIME 5

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

@interface TUSResumableUpload ()

// Readwrite versions of properties in the header
@property (readwrite, strong) NSString *uploadId;
@property (readwrite) BOOL idle;
@property (readwrite) TUSResumableUploadState state;

// Internal state
@property (nonatomic) BOOL cancelled;
@property (nonatomic) BOOL stopped;
@property (nonatomic, weak) id<TUSResumableUploadDelegate> delegate; // Current upload offset
@property (nonatomic) long long offset; // Current upload offset
@property (nonatomic, strong) NSURL *uploadUrl; // Target URL for file
@property (nonatomic, strong) NSDictionary *uploadHeaders;
@property (nonatomic, strong) NSDictionary <NSString *, NSString *> *metadata;
@property (nonatomic, strong) TUSData *data;
@property (nonatomic, strong) NSURLSessionTask *currentTask; // Nonatomic because we know we will assign it, then start the thread that will remove it.
@property (nonatomic, strong) NSURL *fileUrl; // File URL for saving if we created our own TUSData
@property (readonly) long long length;
@property (nonatomic) int rertyCount; // Number of times to try
@property (nonatomic) int attempts; // Number of times tried


@property (nonatomic) long long chunkSize; //how big chunks we send to the server

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
 Make the next call on this upload
 */
- (BOOL) continueUpload;

/**
 Private designated initializer
 No parameters are modified or checked in any way except for state.
 */
- (instancetype _Nullable) initWithUploadId:(NSString *)uploadId
                                       file:(NSURL* _Nullable)fileUrl
                                   delegate:(id<TUSResumableUploadDelegate> _Nonnull)delegate
                              uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              finalMetadata:(NSDictionary <NSString *, NSString *>* _Nonnull)metadata
                                      state:(TUSResumableUploadState)state
                                  uploadUrl:(NSURL * _Nullable)uploadUrl;

@end


@implementation TUSResumableUpload

- (instancetype _Nullable)initWithUploadId:(NSString * _Nonnull)uploadId
                                      file:(NSURL * _Nonnull)fileUrl
                                    retry:(int)retryCount
                                  delegate:(id <TUSResumableUploadDelegate> _Nonnull)delegate
                             uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                                  metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata
                                 uploadUrl:(NSURL * _Nonnull)uploadUrl

{
    if (!fileUrl.fileURL){
        NSLog(@"URL provided to TUSResumableUpload is not a file URL: %@", fileUrl);
        return nil;
    }

    // Set up metadata with filename
    NSMutableDictionary *uploadMetadata = [NSMutableDictionary new];
    uploadMetadata[@"filename"] = fileUrl.filePathURL.lastPathComponent;
    if (metadata){
        [uploadMetadata addEntriesFromDictionary:metadata];
    }

    return [self initWithUploadId:uploadId
                             file:fileUrl
                            retry:retryCount
                         delegate:delegate
                    uploadHeaders:headers
                    finalMetadata:uploadMetadata
                            state:TUSResumableUploadStateUploadingFile
                        uploadUrl:uploadUrl];

}

- (instancetype _Nullable)initWithUploadId:(NSString * _Nonnull)uploadId
                                      file:(NSURL * _Nonnull)fileUrl
                                    retry:(int)retryCount
                                  delegate:(id <TUSResumableUploadDelegate> _Nonnull)delegate
                             uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                                  metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata

{
    if (!fileUrl.fileURL){
        NSLog(@"URL provided to TUSResumableUpload is not a file URL: %@", fileUrl);
        return nil;
    }
    
    // Set up metadata with filename
    NSMutableDictionary *uploadMetadata = [NSMutableDictionary new];
    uploadMetadata[@"filename"] = fileUrl.filePathURL.lastPathComponent;
    if (metadata){
        [uploadMetadata addEntriesFromDictionary:metadata];
    }
    
    return [self initWithUploadId:uploadId
                             file:fileUrl
                            retry:retryCount
                         delegate:delegate
                    uploadHeaders:headers
                    finalMetadata:uploadMetadata
                            state:TUSResumableUploadStateCreatingFile
                        uploadUrl:nil];
    
}


/**
 Private designated initializer
 No parameters are modified or checked in any way except for state.
 */
- (instancetype _Nullable) initWithUploadId:(NSString *)uploadId
                                       file:(NSURL* _Nullable)fileUrl
                                      retry:(int)retryCount
                                   delegate:(id<TUSResumableUploadDelegate> _Nonnull)delegate
                              uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              finalMetadata:(NSDictionary <NSString *, NSString *>* _Nonnull)metadata
                                      state:(TUSResumableUploadState)state
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
        _chunkSize = -1;
        _rertyCount = retryCount;
        _attempts = 0;
        
        if (_state != TUSResumableUploadStateComplete){
            _data = [[TUSFileData alloc] initWithFileURL:fileUrl];
            if (!_data){
                NSLog(@"Error creating TUSFileData object with url %@", fileUrl);
                return nil;
            }
        }
        [self.delegate saveUpload:self];
    }
    return self;
}

#pragma mark public methods
-(BOOL)cancel
{
    if([self stop]){
        self.cancelled = YES;
        [self.delegate removeUpload:self];
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)stop
{
    self.stopped = YES;
    if (self.currentTask){
        [self.currentTask cancel];
    }
    [self.data close];
    return YES;
}

- (BOOL)resume
{
    if (self.cancelled || self.complete){
        return NO;
    }
    [self.data open]; //Re-open data
    self.stopped = NO; // Un-stop
    return [self continueUpload];
}

#pragma mark property getters and setters
- (long long) length {
    return self.data.length;
}

- (BOOL)complete
{
    return self.state == TUSResumableUploadStateComplete;
}

- (void)setChunkSize:(long long)chunkSize {
    _chunkSize = chunkSize;
}

#pragma mark internal methods
-(void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    // When notified of upload progress by the TUSSession, send it to the progress block
    if (self.state == TUSResumableUploadStateUploadingFile && self.currentTask == task && self.progressBlock){
        self.progressBlock(totalBytesSent + self.offset, self.length); // Report progress from current offset, which is where the upload task started.
    }
}

#pragma mark private methods
-(BOOL)continueUpload
{
    // If the process is idle, need to begin at current state
    if (self.idle && !self.stopped) {
        switch (self.state) {
            case TUSResumableUploadStateCreatingFile:
                return [self createFile];
            case TUSResumableUploadStateCheckingFile:
                return [self checkFile];
            case TUSResumableUploadStateUploadingFile:
                return [self uploadFile];
            case TUSResumableUploadStateComplete:
            default:
                return NO;
        }
    }
    return NO;
}

- (BOOL)createFile
{
    self.state = TUSResumableUploadStateCreatingFile;
    self.offset = 0; // Reset the offset to zero if we're creating a new file.
    
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
    NSString* stripColon = [[formattedMetadata componentsJoinedByString:@","] stringByReplacingOccurrencesOfString:@":" withString:@""];
    [mutableHeader setObject:stripColon forKey:@"Upload-Metadata"];
    
    // Add custom headers after the filename, as the upload-metadata may be customized
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    
    // Set the version & length last as they are determined by the uploader
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", size] forKey:HTTP_UPLOAD_LENGTH];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    
    NSURL *createUploadURL = self.delegate.createUploadURL;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:createUploadURL
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:mutableHeader];
    
    __weak TUSResumableUpload * weakself = self;
    
    #if TARGET_OS_IPHONE
    UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [weakself cancel];
    }];
    #endif

    self.currentTask = [self.delegate.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (weakself.currentTask){ // Should only be false if self has been destroyed, but we need to account for that because of the removeTask call.
            [weakself.delegate removeTask:weakself.currentTask];
            weakself.currentTask = nil;
        }
        
        NSUInteger delayTime = 0; // No delay
        NSHTTPURLResponse * httpResponse;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        if (error != nil || httpResponse == nil){
            switch(error.code){
                case NSURLErrorBadURL:
                case NSURLErrorUnsupportedURL:
                case NSURLErrorCannotFindHost:
                    TUSLog(@"Unrecoverable error during attempt to create file");
                    if([weakself stop]){
                        TUSUploadFailureBlock block = weakself.failureBlock;
                        if (block){
                            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                                block(error);
                            }];
                        }
                    }
                    break;
                default:
                    self.attempts++;
                    if (self.rertyCount == -1){
                        TUSLog(@"Infinite retry.");
                    }else if (self.attempts >= self.rertyCount){
                        [weakself stop];
                    }
                    //TODO: Fail after a certain number of delayed attempts
                    delayTime = DELAY_TIME;
                    TUSLog(@"Server not responding or error. Trying again. Attempt %i",
                           self.attempts);            }
        } else if (httpResponse.statusCode >= 500 && httpResponse.statusCode < 600) {
            TUSLog(@"Server error, stopping");
            [weakself stop]; // Will prevent continueUpload from doing anything
            // Make the callback after the current operation so that the rest of the method will finish.
            // Store the block so that we know it will be non-nil in the closure.
            TUSUploadFailureBlock block = weakself.failureBlock;
            if (block) {
                NSInteger statusCode = httpResponse.statusCode;
                [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                    block([[NSError alloc] initWithDomain:TUSErrorDomain code:TUSResumableUploadErrorServer userInfo:@{@"responseCode": @(statusCode)}]);
                }];
            }
        } else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 204){
            self.attempts++;
            if (self.rertyCount == -1){
                TUSLog(@"Infinite retry.");
            }else if (self.attempts >= self.rertyCount){
                [weakself stop];
            }
            //TODO: FAIL after a certain number of errors.
            delayTime = DELAY_TIME;
            TUSLog(@"Server responded to create file with %ld. Trying again. Attempt %i",
                   (long)httpResponse.statusCode, self.attempts);
        } else {
            // Got a valid status code, so update url
            NSString *location = [httpResponse.allHeaderFields valueForKey:HTTP_LOCATION];
            weakself.uploadUrl = [NSURL URLWithString:location relativeToURL:createUploadURL];
            if (weakself.uploadUrl) {
                // If we got a valid URL, set the new state to uploading.  Otherwise, will try creating again.k
                TUSLog(@"Created resumable upload at %@ for id %@", weakself.uploadUrl, weakself.uploadId);
                weakself.state = TUSResumableUploadStateUploadingFile;
            }
        }
        weakself.idle = YES;
        [weakself.delegate saveUpload:weakself]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        #if TARGET_OS_IPHONE
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        #elif defined TARGET_OS_OSX
            [weakself cancel];
        #endif
        
        if (delayTime > 0) {
            __weak NSOperationQueue *weakQueue = [NSOperationQueue currentQueue];
            // Delay some time before we try again.  We use a weak queue pointer because if the queue goes away, presumably the session has too (the session should have a strong pointer to the queue).
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // We use the main queue instead of this queue because we do not know this NSOperationQueue's GCD queue.
                [weakQueue addOperationWithBlock:^{
                    [weakself continueUpload]; // Continue upload on the queue all of the upload operations are on.
                }];
            });
        } else {
            [weakself continueUpload]; // Continue upload on the queue we were previously on.
        }
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}



- (BOOL) checkFile
{
    self.state = TUSResumableUploadStateCheckingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.uploadUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:mutableHeader];
    
    __weak TUSResumableUpload * weakself = self;
    #if TARGET_OS_IPHONE
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [weakself cancel];
        }];
    #endif
    self.currentTask = [self.delegate.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (weakself.currentTask){ // Should only be false if self has been destroyed, but we need to account for that because of the removeTask call.
            [weakself.delegate removeTask:weakself.currentTask];
            weakself.currentTask = nil;
        }
        NSUInteger delayTime = 0; // No delay
        NSHTTPURLResponse * httpResponse;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
        }
        if (error != nil || httpResponse == nil){
            switch(error.code){
                case NSURLErrorBadURL:
                case NSURLErrorUnsupportedURL:
                case NSURLErrorCannotFindHost:
                    TUSLog(@"Unrecoverable error during attempt to check file");
                    if([weakself stop]){
                        TUSUploadFailureBlock block = weakself.failureBlock;
                        if (block){
                            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                                block(error);
                            }];
                        }
                    }
                    break;
                case NSURLErrorTimedOut:
                case NSURLErrorNotConnectedToInternet:
                default:
                    //TODO: Fail after a certain number of delayed attempts
                    delayTime = DELAY_TIME;
                    TUSLog(@"Error or no response during attempt to check file, retrying");
            }
        } else if (httpResponse.statusCode == 423) {
            // We only check 423 errors in checkFile because the other methods will properly handle locks with their generic error handling.
            TUSLog(@"File is locked, waiting and retrying");
            delayTime = DELAY_TIME; // Delay to wait for locks.
        } else if (httpResponse.statusCode >= 500 && httpResponse.statusCode < 600) {
            TUSLog(@"Server error, stopping");
            [weakself stop]; // Will prevent continueUpload from doing anything
            // Make the callback after the current operation so that the rest of the method will finish.
            // Store the block so that we know it will be non-nil in the closure.
            TUSUploadFailureBlock block = weakself.failureBlock;
            if (block) {
                NSInteger statusCode = httpResponse.statusCode;
                [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                    block([[NSError alloc] initWithDomain:TUSErrorDomain code:TUSResumableUploadErrorServer userInfo:@{@"responseCode": @(statusCode)}]);
                }];
            }
        } else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 204){
            TUSLog(@"Server responded to file check with %ld. Creating file",
                   (long)httpResponse.statusCode);
            weakself.state = TUSResumableUploadStateCreatingFile;
        } else {
            // Got a valid status code, so update state and continue upload.
            [weakself updateStateFromHeaders:httpResponse.allHeaderFields];
        }
        weakself.idle = YES;
        [weakself.delegate saveUpload:weakself]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        #if TARGET_OS_IPHONE
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        #elif defined TARGET_OS_OSX
            [weakself cancel];
        #endif
        if (delayTime > 0) {
            __weak NSOperationQueue *weakQueue = [NSOperationQueue currentQueue];
            // Delay some time before we try again.  We use a weak queue pointer because if the queue goes away, presumably the session has too (the session should have a strong pointer to the queue).
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // We use the main queue instead of this queue because we do not know this NSOperationQueue's GCD queue.
                [weakQueue addOperationWithBlock:^{
                    [weakself continueUpload]; // Continue upload on the queue all of the upload operations are on.
                }];
            });
        } else {
            [weakself continueUpload]; // Continue upload on the queue we were previously on.
        }
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}

-(BOOL)uploadFile
{
    self.state = TUSResumableUploadStateUploadingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", self.offset] forKey:HTTP_OFFSET];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    [mutableHeader setObject:@"application/offset+octet-stream" forKey:@"Content-Type"];

    TUSLog(@"Resuming upload to %@ with id %@ from offset %lld",
           self.uploadUrl, self.uploadId, self.offset);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.uploadUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PATCH];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:mutableHeader];
    
    [self.data setOffset:self.offset]; // Advance the offset of data to the expected value
    
    //If we are using chunked sizes, set the chunkSize and retrieve the data
    //with the offset and size of self.chunkSize
    if (self.chunkSize > 0) {
        request.HTTPBody = [self.data dataChunk:self.chunkSize];
        TUSLog(@"Uploading chunk sized %lu / %lld ", request.HTTPBody.length, self.chunkSize);
    } else {
        request.HTTPBodyStream = self.data.dataStream;
    }
    
    __weak TUSResumableUpload * weakself = self;
    #if TARGET_OS_IPHONE
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [weakself cancel];
        }];
    #endif
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
            TUSLog(@"Error or no response during attempt to upload file, checking state");
            // No need to delay, because we are changing states - if there is a network or server error, it will keep delaying there
            weakself.state = TUSResumableUploadStateCheckingFile;
        } else if (httpResponse.statusCode >= 500 && httpResponse.statusCode < 600) {
            TUSLog(@"Server error, stopping");
            weakself.state = TUSResumableUploadStateCheckingFile;
            [weakself stop]; // Will prevent continueUpload from doing anything
            // Make the callback after the current operation so that the rest of the method will finish.
            // Store the block so that we know it will be non-nil in the closure.
            TUSUploadFailureBlock block = weakself.failureBlock;
            if (block) {
                NSInteger statusCode = httpResponse.statusCode;
                [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                    block([[NSError alloc] initWithDomain:TUSErrorDomain code:TUSResumableUploadErrorServer userInfo:@{@"responseCode": @(statusCode)}]);
                }];
            }
        } else if (httpResponse.statusCode < 200 || httpResponse.statusCode > 204){
            TUSLog(@"Invalid status code (%ld) during attempt to upload, checking state", (long)httpResponse.statusCode);
            // No need to delay, because we are changing states: if there is a network or server error, it will delay in the checking state
            weakself.state = TUSResumableUploadStateCheckingFile;
        } else {
            // Got an "OK" response
            [weakself updateStateFromHeaders:httpResponse.allHeaderFields];
        }
        weakself.idle = YES;
        [weakself.delegate saveUpload:weakself]; // Save current state for reloading - only save when we get a call back, not at the start of one (because this is the only time the state changes)
        #if TARGET_OS_IPHONE
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        #elif defined TARGET_OS_OSX
            [weakself cancel];
        #endif
        [weakself continueUpload]; // Continue upload, not resume, because we do not want to continue if cancelled.
    }];
    [self.delegate addTask:self.currentTask forUpload:self];
    self.idle = NO;
    [self.currentTask resume]; // Now everything done on currentTask will be done in the callbacks.
    return YES;
}

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
            if (self.progressBlock)
                self.progressBlock(self.length, self.length); // If there is a progress block, report complete progress
            self.state = TUSResumableUploadStateComplete;
            [self.data stop];
            [self.delegate removeUpload:self];
            if(self.resultBlock){
                self.resultBlock([self.uploadUrl copy]);
            }
        } else {
            TUSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
                   self.uploadUrl, self.uploadId, serverOffset, rangeHeader);
            self.offset = serverOffset;
            self.state = TUSResumableUploadStateUploadingFile;
        }
    } else {
        TUSLog(@"No header received during request for %@, so checking file", self.uploadUrl);
        // We didn't get an offset header, so we need to run the check again
        self.state = TUSResumableUploadStateCheckingFile;
    }
}



#pragma mark private and internal persistence functions



-(NSDictionary *) serialize
{
    
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
             STORE_KEY_UPLOAD_URL:  self.state == TUSResumableUploadStateCreatingFile? @"": self.uploadUrl.absoluteString, //If we are creating the file, there is no upload URL
             STORE_KEY_LENGTH: @(self.length),
             STORE_KEY_LAST_STATE: @(self.state),
             STORE_KEY_METADATA: self.metadata,
             STORE_KEY_UPLOAD_HEADERS: self.uploadHeaders,
             STORE_KEY_FILE_URL: fileUrlData};
    
}

-(instancetype)initWithDictionary:(NSDictionary *)serializedUpload delegate:(id<TUSResumableUploadDelegate>)delegate
{
    // If there is no data associated with the upload ID
    if (serializedUpload == nil) {
        return nil;
    }
    
    // Get parameters
    NSNumber *uploadId = serializedUpload[STORE_KEY_ID];
    NSNumber *expectedLength = serializedUpload[STORE_KEY_LENGTH];
    NSNumber *stateObj = serializedUpload[STORE_KEY_LAST_STATE];
    TUSResumableUploadState state = stateObj.unsignedIntegerValue;
    NSDictionary *metadata = serializedUpload[STORE_KEY_METADATA];
    NSDictionary *headers = serializedUpload[STORE_KEY_UPLOAD_HEADERS];
    NSDictionary *uploadUrl = [NSURL URLWithString:serializedUpload[STORE_KEY_UPLOAD_URL]];
    
    NSURL * savedDelegateEndpoint = [NSURL URLWithString:serializedUpload[STORE_KEY_DELEGATE_ENDPOINT]];
    if (![savedDelegateEndpoint.absoluteString isEqualToString:delegate.createUploadURL.absoluteString]){ // Check saved delegate endpoint
        NSLog(@"Delegate URL in stored dictionary for %@ (%@) does not match the one in the passed-in delegate %@", uploadId, savedDelegateEndpoint, delegate.createUploadURL);
        return nil;
    }
    
    NSURL *fileUrl = nil;
    if(serializedUpload[STORE_KEY_FILE_URL] != [NSNull null]){
        NSError *error;
        fileUrl = [NSURL URLByResolvingBookmarkData:serializedUpload[STORE_KEY_FILE_URL] options:0 relativeToURL:nil bookmarkDataIsStale:nil error:&error];
        if (error != nil){ // Assuming fileUrl must be non-nil if there is no error
            NSLog(@"Error loading file URL from stored data for upload %@", uploadId);
            return nil;
        }
        // Check file length
        NSNumber *fileSize = nil;
        [fileUrl getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&error];
        if (error != nil){
            NSLog(@"Error loading size of file saved at %@ when restoring upload %@", fileUrl, uploadId);
            return nil;
        }
        
        if (fileSize.unsignedLongLongValue != expectedLength.unsignedLongLongValue){
            NSLog(@"Expected file size (%ulld) for saved upload %@ does not match actual file size (%ulld)", fileSize.unsignedLongLongValue, uploadId, expectedLength.unsignedLongLongValue);
            return nil;
        }
    } else if (state != TUSResumableUploadStateComplete) { // If we do not have a file url and the upload isn't complete, then we were reloading using the wrong method.
        NSLog(@"Attempt to reload non-file upload using file-based upload restore method");
        //TODO: Implement code to resume a non-file-based upload
        return nil;
    }
    
    // If the upload was previously uploading, we need to do a check before we can continue.
    if (state == TUSResumableUploadStateUploadingFile){
        state = TUSResumableUploadStateCheckingFile;
    }
    
    return [self initWithUploadId:uploadId
                             file:fileUrl
                         delegate:delegate
                    uploadHeaders:headers
                    finalMetadata:metadata
                            state:state
                        uploadUrl:uploadUrl];
}

@end
