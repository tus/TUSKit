//
//  TUSBackgroundSession.m
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import "TUSBackgroundSession.h"
#import "TUSBackgroundUpload.h"
#import "TUSUploadStore.h"

@interface TUSBackgroundSession()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *endpoint;
@property (nonatomic, strong) NSMutableArray *uploadTasks;
@property (nonatomic, strong) TUSUploadStore *store;
@property (nonatomic, strong) NSMutableDictionary <NSString *, TUSBackgroundUpload> backgroundUploads;
@property BOOL allowsCellularAccess;

@end

@implementation TUSBackgroundSession

- (id)initWithEndpoint:(NSURL *)endpoint
  allowsCellularAccess:(BOOL)allowsCellularAccess
{
    self = [super init];
    
    if (self) {
        NSString *identifier = [[NSString alloc] initWithString:@"TUSProtocolSession:" stringByAppendingString:endpoint];
        NSURLSessionConfiguration *backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        backgroundConfiguration.allowsCellularAccess = allowsCellularAccess;
        
        self.session = [NSURLSession sessionWithConfiguration:backgroundConfiguration delegate:self delegateQueue:nil];
        self.store = [[TUSUploadStore alloc] init];
        self.endpoint = endpoint;
        self.allowsCellularAccess = allowsCellularAccess;
        self.backgroundUploads = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)initiateBackgroundUpload:(NSURL *)fileUrl withHeaders:(NSDictionary *)headers
{
    TUSBackgroundUpload *backgroundUpload = [[TUSBackgroundUpload alloc] initWithUrl:self._endpoint
                                                                          sourceFile:fileUrl
                                                                       uploadHeaders:headers
                                                                         uploadStore:self.store];
    NSURLSessionTask *uploadTask = [upload makeNextCallWithSession:self.session];
    
    // Save in memory
    self.backgroundUploads[backgroundUpload.id] = backgroundUpload;
    
    // Save to the store
    [self saveUploadTaskToStore:uploadTask backgroundUpload:backgroundUpload];
    
    //Task begins in a suspended state, call resume
    [uploadTask resume];
}

#pragma mark private methods
- (TUSBackgroundUpload *)getBackgroundUploadById:(NSString *)uploadId
{
    
    // First check in memory
    TUSBackgroundUpload *backgroundUpload = [self.backgroundUploads objectForKey:uploadId];
    
    // If doesn't exist, pull from store and save in memory
    if (backgroundUpload == nil) {
        TUSBackgroundUpload *backgroundUpload = [TUSBackgroundUpload loadUploadWithId:uploadId fromStore:self.store];
        self.backgroundUploads[backgroundUpload.id] = backgroundUpload;
    }
    
    return backgroundUpload;
}

- (TUSBackgroundUpload *)getUploadForTaskId:(NSUInteger)uploadTaskId
{
    NSString *backgroundUploadId = [self.store loadBackgroundUploadId:uploadTaskId];

    if (backgroundUploadId != nil) {
        return [self getBackgroundUploadById:backgroundUploadId];
    }
    
    return nil;
}

- (NSArray *)loadUploads:(NSArray *)uploadTaskIds
{
    NSMutableArray *backgroundUploads = [];
    
    //For each record in the store, load the background upload and resume
    for (var i=0; i < [uploadTaskIds count]; i++) {
        TUSBackgroundUpload *backgroundUpload = [self getBackgroundUploadById:backgroundUploads[i]];
        NSURLSessionTask *uploadTask = [backgroundUpload makeNextCallWithSession:self.session];
        [uploadTask resume];
    }
    
    return backgroundUploads;
}

- (void)continueUploads
{
    // First fetch all the background upload identifiers
    NSArray *backgroundUploadIds = [self.store loadAllBackgroundUploadIds];
    NSMutableArray *backgroundUploads = [];
    
    // Attempt to pull the background upload from the session's in memory store
    // ONLY if it does not exist should it be pulled from the store (prevent duplicate object creation)
    for (int i=0; i < [backgroundUploadIds count]; i++) {
        TUSBackgroundUpload *backgroundUpload = [self.backgroundUploads objectForKey:backgroundUploadsId[i]];
        
        if (backgroundUpload != nil) {
            [backgroundUploads abbObject:backgroundUpload];
        } else {
            TUSBackgroundUpload *storedUpload = [TUSBackgroundUpload loadUploadWithId:backgroundUploadIds[i] fromStore:self.store];
            
            if (storedBackground != nil) {
                [backgroundUploads addObject:storedUpload];
            }
        }
    }
    
    // For each background upload, retrieve an upload task and resume
    for (int i=0; i < [backgroundUploads count]; i++) {
        
        NSURLSessionTask *uploadTask = [backgroundUploads[i] makeNextCallWithSession:self.session];
        
        [uploadTask resume];
    }
}

- (void)saveUploadTaskToStore:(NSURLSessionTask *)uploadTask backgroundUpload:(TUSBackgroundUpload *)backgroundUpload
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:uploadTask.taskIdentifier];
    
    // Save the mappings
    [self.store saveBackgroundTaskId:uploadTask.taskIdentifier withBackgroundUploadId:backgroundUpload.id];
}

- (void)removeUploadTaskFromStore:(NSUInteger)uploadTaskId
{
    [self.store removeUploadTaskId:uploadTaskId];
}

// When the TUSBackgroundUpload is fully completed, also remove it from the dictionary and call close on it/file upload
- (void)removeBackgroundUpload:(NSString *)uploadId
{
    [self.backgroundUploads removeObjectForKey:uploadId];
    [self.store removeBackgroundUpload:uploadId];
}

#pragma mark NSURLSession Delegate methods

- (void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:task.id]];
    
    [backgroundUpload task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}

- (void)dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:dataTask.id];
    
    [backgroundUpload task:dataTask didReceiveResponse:response];
}

- (void)task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:task.id];
    
    [backgroundUpload task:task didCompleteWithError:error];
}

#pragma mark NSURLSession Delegate methods
- downloadTaskWithResumeData:completionHandler:

#pragma NSURLSessionDownloadDelegate methods
- URLSession:didBecomeInvalidWithError:
- URLSessionDidFinishEventsForBackgroundURLSession:

#pragma mark NSURLSessionDownloadTask methods
- URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes
- URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite
- URLSession:downloadTask:didFinishDownloadingToURL:


@end
