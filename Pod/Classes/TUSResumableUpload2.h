//
//  TUSResumableUpload2.h
//  tus-ios-client-demo
//
//  Originally Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for TUSSession completed by Findyr
//  Copyright (c) 2016 Findyr

@import Foundation;

typedef NS_ENUM(NSInteger, TUSSessionUploadState) {
    TUSSessionUploadStateCreatingFile,
    TUSSessionUploadStateCheckingFile,
    TUSSessionUploadStateUploadingFile,
    TUSSessionUploadStateComplete
};

@interface TUSResumableUpload2 : NSObject
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
@property (readonly) TUSSessionUploadState state;

- (BOOL) cancel;
/**
 Resume the upload if it was cancelled or not yet started
 */
- (BOOL) resume;
@end

