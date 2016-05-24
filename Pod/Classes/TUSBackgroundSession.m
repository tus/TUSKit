//
//  TUSBackgroundSession.m
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import "TUSBackgroundSession.h"
#import "TUSBackgroundUpload.h"

@implementation TUSBackgroundSession

- (instancetype)initWithEndpoint:(NSURL *)endpoint
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
    }
    
    return self;
}

- (void) initiateBackgroundUpload:(NSURL *)fileUrl
{
    TUSBackgroundUpload *backgroundUpload = [[TUSBackgroundUpload alloc] initWithUrl:self._endpoint
                                                                          sourceFile:fileUrl];
    NSURLSessionTask *uploadTask = [upload makeNextCallWithSession:self.session];
    
    // Save to the store
    [self saveUploadTask:uploadTask];
    
    //Task begins in a suspended state, call resume
    [uploadTask resume];

}

- (TUSBackgroundUpload *)loadSavedBackgroundUpload:(NSNumber *)uploadTaskId
{
    NSString *backgroundUploadId = [self.store loadBackgroundUploadId:uploadTaskId];

    if (backgroundUploadId != nil) {
        return [TUSBackgroundUpload loadUploadWithId:uploadId fromStore:self.store];
    }
    
    return nil;
}

- (NSArray *) loadSavedUploads:(NSArray *)uploadTaskIds
{
    NSMutableArray *backgroundUploads = [];
    
    //For each record in the store, load the background upload and resume
    for (var i=0; i < [uploadTaskIds count]; i++) {
        TUSBackgroundUpload *backgroundUpload = [self loadSavedBackgroundUpload:uploadTaskIds[i]];
        
        if (backgroundUpload != nil) {
            [backgroundUploads addObject:backgroundUpload];
        }
        
    }
    
    return backgroundUploads;
}

- (void) resumeUploads:(NSArray *)backgroundUploads
{
    for (var i=0; i < [backgroundUploads count]; i++) {
        NSURLSessionTask *uploadTask = [backgroundUploads[i] makeNextCallWithSession:self.session];
        
        [uploadTask resume];
    }
}

- (void) suspendUpload:(NSURLSessionTask *)uploadTask
{
    [uploadTask suspend];
}

- (void) saveUploadTask:(NSURLSessionTask *)uploadTask
{
    NSNumber *uploadTaskId = [[NSNumber alloc] initWithInteger:uploadTask.taskIdentifier];
    TUSBackgroundUpload *backgroundUpload = [self loadSavedBackgroundUpload:uploadTaskId];
    
    // Save the mappings
    [self.store saveBackgroundTaskId:uploadTaskId withBackgroundUploadId:backgroundUpload.id]
    [self.store saveBackgroundUploadWithId:backgroundUpload];
}

#pragma NSURLSession Delegate methods

-(void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    TUSBackgroundUpload *backgroundUpload = [self loadSavedBackgroundUpload:[[NSNumber alloc] initWithInteger:task.id]];
    
    [backgroundUpload task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}

// For a data task (why implemented?)
-(void)dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    TUSBackgroundUpload *backgroundUpload = [self loadSavedBackgroundUpload:[[NSNumber alloc] initWithInteger:dataTask.id]];
    
    [backgroundUpload task:dataTask didReceiveResponse:response];
}

-(void) task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    TUSBackgroundUpload *backgroundUpload = [self loadSavedBackgroundUpload:[[NSNumber alloc] initWithInteger:task.id]];
    
    [backgroundUpload task:task didCompleteWithError:error];
}

#pragma mark NSURLSession Delegate methods
downloadTaskWithResumeData:completionHandler:

#pragma NSURLSessionDownloadDelegate methods
- URLSession:didBecomeInvalidWithError:
- URLSessionDidFinishEventsForBackgroundURLSession:

#pragma mark NSURLSessionDownloadTask methods
- URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes
- URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite
- URLSession:downloadTask:didFinishDownloadingToURL:
- URLSession:task:didCompleteWithError:


@end
