//
//  TusBackgroundUpload.h
//  tus-ios-client-demo
//
//  Originally Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.

@import Foundation;
#import "TUSUploadStore.h"

typedef void (^TUSUploadResultBlock)(NSURL* fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* error);
typedef void (^TUSUploadProgressBlock)(NSUInteger bytesWritten, NSUInteger bytesTotal);

@interface TUSBackgroundUpload : NSObject

@property (readwrite, copy) TUSUploadResultBlock resultBlock;
@property (readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) TUSUploadProgressBlock progressBlock;
@property (readonly) NSString *id;

- (instancetype)initWithURL:(NSString *)url
             data:(TUSData *)data
      fingerprint:(NSString *)fingerprint
    uploadHeaders:(NSDictionary *)headers
      fileName:(NSString *)fileName;

- (NSString *) makeNextCallWithSession:(NSURLSession *)session;

/**
 Recreate a TUSBackgroundUpload from a dictionary
 */
+(instancetype)loadUploadWithId:(NSString *)uploadId fromStore:(TUSUploadStore *)store;

- (id)initWithURL:(NSURL *)url
       sourceFile:(NSURL *)sourceFile
    uploadHeaders:(NSDictionary *)headers
      uploadStore:(TUSUploadStore *)store;
@end