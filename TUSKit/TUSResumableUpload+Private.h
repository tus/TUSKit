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
@required
/**
 The session that should be used for all HTTP requests by this upload
 */
@property (readonly) NSURLSession * _Nullable session;

/**
 The URL that is used to create a file on the server
 */
@property (readonly) NSURL * _Nonnull createUploadURL;

/**
 Add an NSURLSessionTask that should be associated with this upload
 */
-(void)addTask:(NSURLSessionTask * _Nonnull)task forUpload:(TUSResumableUpload * _Nonnull)upload;

/**
 Stop tracking an NSURLSessionTask
 */
-(void)removeTask:(NSURLSessionTask * _Nonnull)task;

/**
 Save/update the TUSResumableUpload in the delegate's storage
 */
-(void)saveUpload:(TUSResumableUpload * _Nonnull)upload;

/**
 Stop tracking an TUSResumableUpload
 */
-(void)removeUpload:(TUSResumableUpload * _Nonnull)upload;
@end


/**
 Module-internal methods for TUSResumableUpload
 */
@interface TUSResumableUpload(Internal)
/**
 Initializer methods
 */

/** Initialize from a serialized dictionary */
- (instancetype _Nullable)initWithDictionary:(NSDictionary * _Nonnull)serializedUpload delegate:(id<TUSResumableUploadDelegate> _Nonnull)delegate;


- (instancetype _Nullable)initWithUploadId:(NSString * _Nonnull)uploadId
                                      file:(NSURL * _Nonnull)fileUrl
                                    retry:(int)retryCount
                                  delegate:(id <TUSResumableUploadDelegate> _Nonnull)delegate
                             uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                                  metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata;

- (instancetype _Nullable)initWithUploadId:(NSString * _Nonnull)uploadId
                                      file:(NSURL * _Nonnull)fileUrl
                                    retry:(int)retryCount
                                  delegate:(id <TUSResumableUploadDelegate> _Nonnull)delegate
                             uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                                  metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata
                                 uploadUrl:(NSURL * _Nonnull)uploadUrl;

/**
 Progress callback method for a task associated with this upload. 
 */
-(void)task:(NSURLSessionTask * _Nonnull)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

/** Serialize to a dictionary for saving */
-(NSDictionary * _Nonnull) serialize;
@end

#endif /* TUSResumableUpload_Private_h */
