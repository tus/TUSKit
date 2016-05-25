//
//  TUSBackgroundSession.h
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import <Foundation/Foundation.h>
#import "TUSUploadStore.h"

@interface TUSBackgroundSession : NSObject <NSURLSessionDelegate>

/**
 Initialize
 */
- (id)initWithEndpoint:(NSURL *)endpoint
  allowsCellularAccess:(BOOL)allowsCellularAccess

/**
 Begin a background upload
 */
- (void) initiateBackgroundUpload:(NSURL *)fileUrl

/**
 Begin a background upload
 */
- (void) saveUploadTask:(NSURLSessionTask *)uploadTask

/**
 Clean up methods
 */
- (void)removeUploadTaskFromStore:(NSUInteger)uploadTaskId
- (void)removeBackgroundUpload:(NSString *)uploadId

/**
 NSURLSession Delegate methods
 */
- (void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
- (void)dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
- (void)task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error

/**
 NSURLSession task methods
 */
- (NSArray *)loadUploads:(NSArray *)uploadTaskIds
- (void)continueUploads:(NSArray *)uploadTasks

@end
