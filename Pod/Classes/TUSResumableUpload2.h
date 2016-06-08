//
//  TUSResumableUpload2.h
//  tus-ios-client-demo
//
//  Originally Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.

@import Foundation;
@class TUSUploadStore;

typedef void (^TUSUploadResultBlock)(NSURL* fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* error);
typedef void (^TUSUploadProgressBlock)(NSUInteger bytesWritten, NSUInteger bytesTotal);

@interface TUSResumableUpload2 : NSObject

@property (atomic, readwrite, copy) TUSUploadResultBlock resultBlock;
@property (atomic, readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (atomic, readwrite, copy) TUSUploadProgressBlock progressBlock;
@property (readonly) NSString *id;

/**
Utility Methods
*/
- (BOOL) isComplete;
- (BOOL) cancel;
- (BOOL) pause;
- (BOOL) resume;


@end

