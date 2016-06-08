//
//  TUSResumableUpload2+Private.h
//  Pods
//
//  Created by Findyr on 6/7/16.
//
//

#ifndef TUSResumableUpload2_Private_h
#define TUSResumableUpload2_Private_h
@import Foundation;
#import "TUSResumableUpload2.h"

// Circular references
@class TUSUploadStore;
@class TUSSession;



/**
 Delegate that provides additional functionality and data that TUSResumableUpload2 needs.
 */
@protocol TUSResumableUpload2Delegate <NSObject>

/**
 The session that should be used for all HTTP requests by this upload
 */
@required
@property (readonly) NSURLSession * _Nullable session;

/**
 The datastore that should be used to save the details about this upload
 */
@required
@property (readonly) TUSUploadStore * _Nonnull store;

/**
 Add an NSURLSessionTask that should be associated with this upload
 */
@required
-(void)addTask:(NSURLSessionTask * _Nonnull)task forUpload:(TUSResumableUpload2 * _Nonnull)upload;

/**
 Stop tracking an NSURLSessionTask
 */
@required
-(void)removeTask:(NSURLSessionTask * _Nonnull)task;
@end


/**
 Module-internal methods for TUSResumableUpload2
 */
@interface TUSResumableUpload2(Internal)
@property (nonatomic, weak) NSURLSession * __nullable session;
/**
 Initializer methods
 */
- (instancetype _Nullable)initWithFile:(NSURL * _Nonnull)fileUrl
                              delegate:(NSObject <TUSResumableUpload2Delegate> * _Nonnull)delegate
                         uploadHeaders:(NSDictionary <NSString *, NSString *>* _Nonnull)headers
                              metadata:(NSDictionary <NSString *, NSString *>* _Nullable)metadata;


+ (instancetype _Nullable)loadUploadWithId:(NSString * _Nonnull)uploadId
                                 fromStore:(TUSUploadStore * _Nonnull)store;

@end

#endif /* TUSResumableUpload2_Private_h */
