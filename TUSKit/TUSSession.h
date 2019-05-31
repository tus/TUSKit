//
//  TUSSession.h
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import <Foundation/Foundation.h>
#import "TUSUploadStore.h"
#import "TUSData.h"
#import "TUSResumableUpload.h"

/**
 Session that manages, creates, and reloads TUS uploads using a single NSURLSession and data store
 
 This is NOT yet thread safe.
 */
@interface TUSSession : NSObject
@property (nonatomic) BOOL allowsCellularAccess;
-(NSURLSession *_Nonnull) session;

/**
 Initialize
 */
- (instancetype _Nonnull)initWithEndpoint:(NSURL * _Nonnull)endpoint
                                dataStore:(TUSUploadStore * _Nonnull)store
                     allowsCellularAccess:(BOOL)allowsCellularAccess;

- (id _Nonnull )initWithEndpoint:(NSURL * _Nonnull)endpoint
             dataStore:(TUSUploadStore * _Nonnull)store
  sessionConfiguration:(NSURLSessionConfiguration * _Nonnull)sessionConfiguration;

/**
 Create an upload, but do not start it
 */
- (TUSResumableUpload * _Nullable) createUploadFromFile:(NSURL * _Nonnull)fileURL
                                                  retry:(int)retryCount
                                                headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                                               metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata;

/**
 Create an upload with a uploadUrl
 */
- (TUSResumableUpload * _Nullable) createUploadFromFile:(NSURL * _Nonnull)fileURL
                                                  retry:(int)retryCount
                                                headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                                               metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata
                                              uploadUrl:(NSURL * _Nonnull)uploadUrl;

/**
 Restore an upload, but do not start it.  Uploads must be restored by ID because file URLs can change between launch.
 */
- (TUSResumableUpload * _Nullable) restoreUpload:(NSString * _Nonnull)uploadId;

//TODO: Allow custom TUSData to be passed in with an upload.


/**
 Restore all saved uploads that do not require new data objects from the data store, but do not start them.
 
 This is not done automatically so that an application can choose which to load into memory.
 
 @returns All uploads currently in memory
 */
-(NSArray <TUSResumableUpload *> * _Nonnull)restoreAllUploads;


/**
 Cancel all pending uploads such that they cannot be resumed
 */
-(NSUInteger)cancelAll;

/**
 Stop all pending uploads such that they can be resumed
 */
-(NSUInteger)stopAll;

/**
 Resume all in-memory uploads.  Return all that have been restarted.
 Uploads that were already in-progress are not returned.
 
 This is not done automatically on restore so that an application can choose which to resume.
 
 @returns All running uploads
 */
-(NSArray <TUSResumableUpload *> * _Nonnull)resumeAll;

@end
