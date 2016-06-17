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
@property BOOL allowsCellularAccess;

/**
 Initialize
 */
- (instancetype)initWithEndpoint:(NSURL *)endpoint
                       dataStore:(TUSUploadStore *)store
            allowsCellularAccess:(BOOL)allowsCellularAccess;

/**
 Create an upload, but do not start it
 */
- (TUSResumableUpload *) createUploadFromFile:(NSURL *)fileURL
                                       headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                                      metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata;

/**
 Restore an upload, but do not start it.  Uploads must be restored by ID because file URLs can change between launch.
 */
- (TUSResumableUpload *) restoreUpload:(NSString *)uploadId;

//TODO: Allow custom TUSData to be passed in with an upload.


/**
 Restore all saved uploads that do not require new data objects from the data store, but do not start them.
 
 This is not done automatically so that an application can choose which to load into memory.
 */
-(NSArray <TUSResumableUpload *> *)restoreAllUploads;


// Cancel all pending uploads
-(NSUInteger)cancelAll;

/**
 Resume all in-memory uploads.  Return all that have been restarted.
 Uploads that were already in-progress are not returned.
 
 This is not done automatically on restore so that an application can choose which to resume.
 */
-(NSArray <TUSResumableUpload *> *)resumeAll;

@end
