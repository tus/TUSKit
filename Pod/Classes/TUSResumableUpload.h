//
//  TUSResumableUpload.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
/*
 Compatibility for tus.io 1.0 developed by HotPoint Social App
 */

@import Foundation;

typedef void (^TUSUploadResultBlock)(NSURL* fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* error);
typedef void (^TUSUploadProgressBlock)(NSInteger bytesWritten, NSInteger bytesTotal);

typedef struct _TUSRange {
    long long first;
    long long last;
} TUSRange;

NS_INLINE TUSRange TUSMakeRange(long long first, long long last) {
    TUSRange r;
    r.first = first;
    r.last = last;
    return r;
}

@class TUSData;

@interface TUSResumableUpload : NSObject <NSURLConnectionDelegate>

@property (readwrite, copy) TUSUploadResultBlock resultBlock;
@property (readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) TUSUploadProgressBlock progressBlock;

- (id)initWithURL:(NSString *)url
             data:(TUSData *)data
      fingerprint:(NSString *)fingerprint
    uploadHeaders:(NSDictionary *)headers;

- (void) start;

@end
