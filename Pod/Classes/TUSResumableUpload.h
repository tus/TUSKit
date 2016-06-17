//
//  TUSResumableUpload.h
//
//  Originally Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr

@import Foundation;

typedef NS_ENUM(NSInteger, TUSResumableUploadState) {
    TUSResumableUploadStateCreatingFile,
    TUSResumableUploadStateCheckingFile,
    TUSResumableUploadStateUploadingFile,
    TUSResumableUploadStateComplete
};


typedef void (^TUSUploadResultBlock)(NSURL* fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* error);
typedef void (^TUSUploadProgressBlock)(NSInteger bytesWritten, NSInteger bytesTotal);

@interface TUSResumableUpload : NSObject
@property (readwrite, copy) TUSUploadResultBlock resultBlock;
@property (readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) TUSUploadProgressBlock progressBlock;

/**
 The unique ID for the upload object
 */
@property (readonly) NSString *uploadId;

/**
 The upload is complete if the file has been completely uploaded to the TUS server
*/
 @property (readonly) BOOL complete;
 

/**
 The upload is idle if no HTTP tasks are currently outstanding for it
 */
@property (readonly) BOOL idle;

/**
 The current state of the upload
 */
@property (readonly) TUSResumableUploadState state;

/**
 Permanently cancel this upload.  If cancelled, it cannot be resumed
 */
-(BOOL)cancel;

/**
 Temporarily stop this upload.
 */
-(BOOL)stop;

/**
 Resume the upload if it was cancelled or not yet started
 */
- (BOOL) resume;
@end

