//
//  TUSResumableUpload+Private.h
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#ifndef TUSResumableUpload_Private_h
#define TUSResumableUpload_Private_h
@import Foundation;
#import "TUSResumableUpload.h"

// Circular references
@class TUSUploadStore;
@class TUSSession;



/**
 Delegate that provides additional functionality and data that TUSResumableUpload needs.
 */
@protocol TUSResumableUploadDelegate <NSObject>

/**
 The session that should be used for all HTTP requests by this upload
 */
@required
@property (readonly) NSURLSession * _Nullable session;

/**
 The URL that is used to create a file on the server
 */
@property (readonly) NSURL * _Nonnull createUploadURL;

/**
 The datastore that should be used to save the details about this upload
 */
@required
@property (readonly) TUSUploadStore * _Nonnull store;

/**
 Add an NSURLSessionTask that should be associated with this upload
 */
@required
-(void)addTask:(NSURLSessionTask * _Nonnull)task forUpload:(TUSResumableUpload * _Nonnull)upload;

/**
 Stop tracking an NSURLSessionTask
 */
@required
-(void)removeTask:(NSURLSessionTask * _Nonnull)task;

/**
 Stop tracking an TUSResumableUpload
 */
@required
-(void)removeUpload:(TUSResumableUpload * _Nonnull)upload;
@end


/**
 Module-internal methods for TUSResumableUpload
 */
@interface TUSResumableUpload(Internal)
@property (nonatomic, weak) NSURLSession * __nullable session;
/**
 Initializer methods
 */
- (instancetype _Nullable)initWithFile:(NSURL * _Nonnull)fileUrl
                              delegate:(id <TUSResumableUploadDelegate> _Nonnull)delegate
                         uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata;


+(instancetype _Nullable)loadUploadWithId:(NSString *)uploadId
                                 delegate:(id<TUSResumableUploadDelegate> _Nonnull)delegate;

/**
 Progress callback method for a task associated with this upload. 
 */
-(void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

@end

#endif /* TUSResumableUpload_Private_h */
