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


typedef void (^TUSUploadResultBlock)(NSURL* _Nonnull fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* _Nonnull error);
typedef void (^TUSUploadProgressBlock)(int64_t bytesWritten, int64_t bytesTotal);

@interface TUSResumableUpload : NSObject<NSCoding>
@property (readwrite, copy) _Nullable TUSUploadResultBlock resultBlock;
@property (readwrite, copy) _Nullable TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) _Nullable TUSUploadProgressBlock progressBlock;

/**
 The unique ID for the upload object
 */
@property (readonly) NSString * _Nonnull uploadId;

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

/**
 Lazily instantiate the chunkSize for the upload
 */
- (void)setChunkSize:(long long)chunkSize;

@end

