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
@property (nonatomic, strong) NSMutableDictionary <NSString *, TUSBackgroundUpload *>* backgroundUploads;
@property BOOL allowsCellularAccess;

@end

@implementation TUSBackgroundSession

- (id)initWithEndpoint:(NSURL *)endpoint
  allowsCellularAccess:(BOOL)allowsCellularAccess
{
    self = [super init];
    
    if (self) {
        NSString *prefix = [[NSString alloc] initWithString:@"TUSProtocolSession:"];
        NSString *identifier = [prefix stringByAppendingString:[endpoint absoluteString]];
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

- (void)initiateBackgroundUpload:(NSURL *)fileUrl headers:(NSDictionary *)headers metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata
{
    TUSBackgroundUpload *backgroundUpload = [[TUSBackgroundUpload alloc] initWithURL:self.endpoint
                                                                          sourceFile:fileUrl
                                                                       uploadHeaders:headers
                                                                            metadata:metadata
                                                                         uploadStore:self.store];
    NSURLSessionTask *downloadTask = [backgroundUpload makeNextCallWithSession:self.session];
    
    // Save in memory
    self.backgroundUploads[backgroundUpload.id] = backgroundUpload;
    
    // Save to the store
    [self saveTaskToStore:downloadTask backgroundUpload:backgroundUpload];
    
    //Task begins in a suspended state, call resume
    [downloadTask resume];
}

- (NSURLSession *)getSession
{
    return self.session;
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

- (NSArray *)loadBackgroundUploads
{
    // First fetch all the stored background upload identifiers
    NSArray *backgroundUploadIds = [self.store loadAllBackgroundUploadIds];
    NSMutableArray *backgroundUploads = [NSMutableArray new];
    
    // Attempt to pull the background upload from the session's in memory store
    // ONLY if it does not exist should the dictionary be pulled from the associated store (prevent duplicate object creation)
    for (int i=0; i < [backgroundUploadIds count]; i++) {
        TUSBackgroundUpload *backgroundUpload = [self.backgroundUploads objectForKey:backgroundUploadIds[i]];
        
        if (backgroundUpload != nil) {
            [backgroundUploads addObject:backgroundUpload];
        } else {
            TUSBackgroundUpload *storedUpload = [TUSBackgroundUpload loadUploadWithId:backgroundUploadIds[i] fromStore:self.store];
            
            if (storedUpload != nil) {
                [backgroundUploads addObject:storedUpload];
            }
        }
    }
    
    return backgroundUploads;
}

- (void)continueUploads
{
    NSArray *backgroundUploads = [self loadBackgroundUploads];
    
    // For each background upload retrieved, proceed with the next call
    for (int i=0; i < [backgroundUploads count]; i++) {
        NSURLSessionTask *uploadTask = [backgroundUploads[i] makeNextCallWithSession:self.session];
        
        [uploadTask resume];
    }
}

- (void)saveTaskToStore:(NSURLSessionTask *)task backgroundUpload:(TUSBackgroundUpload *)backgroundUpload
{
    // Save the mappings
    [self.store saveTaskId:task.taskIdentifier withBackgroundUploadId:backgroundUpload.id];
}

- (void)removeUploadTaskFromStore:(NSUInteger)uploadTaskId
{
    [self.store removeUploadTask:uploadTaskId];
}

// When the TUSBackgroundUpload is fully completed, also remove it from the dictionary and call close on it/file upload
- (void)removeBackgroundUpload:(NSString *)uploadId
{
    [self.backgroundUploads removeObjectForKey:uploadId];
    [self.store removeBackgroundUpload:uploadId];
}

#pragma mark NSURLSession Delegate methods

//- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
//{
//    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:task.taskIdentifier];
//    
//    [backgroundUpload task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
//}
//
//- (void) URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
//{
//    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:dataTask.taskIdentifier];
//    
//    [backgroundUpload dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
//    
//    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
//    
//    if (appState == UIApplicationStateActive) {
//        [backgroundUpload makeNextCallWithSession:session];
//    }
//}

-(void) URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:task.taskIdentifier];
    
    [backgroundUpload task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];

}

-(void) URLSession:(NSURLSession *)session
               task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:task.taskIdentifier];
    
    [backgroundUpload task:task didCompleteWithError:error];
    
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    
    // Only continue if the application is active - otherwise, a manager (implement) should decide
    // to when to make the next call
    if (appState == UIApplicationStateActive) {
            
        NSURLSessionTask *task = [backgroundUpload makeNextCallWithSession:self.session];
            
        // If complete, task will be nil
        if (task != nil) {
            // Save in memory
            self.backgroundUploads[backgroundUpload.id] = backgroundUpload;
                
            // Save to the store
            [self saveTaskToStore:task backgroundUpload:backgroundUpload];
                
            //Task begins in a suspended state, call resume
            [task resume];
        } else {
            // If there are no more uploads to resume, cancel the session
            [self.session invalidateAndCancel];
        }
    }
}

-(void) URLSession:(NSURLSession *) session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    TUSBackgroundUpload *backgroundUpload = [self getUploadForTaskId:downloadTask.taskIdentifier];
    
    [backgroundUpload downloadTask:downloadTask didFinishDownloadingToURL:location];
}

#pragma mark NSURLSession Delegate methods
//- downloadTaskWithResumeData:completionHandler:

#pragma NSURLSessionDownloadDelegate methods
//- URLSession:didBecomeInvalidWithError:
//- URLSessionDidFinishEventsForBackgroundURLSession:

#pragma mark NSURLSessionDownloadTask methods
//- URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes
//- URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite
//- URLSession:downloadTask:didFinishDownloadingToURL:


@end
