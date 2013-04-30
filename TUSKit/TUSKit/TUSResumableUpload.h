//
//  TUSResumableUpload.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <Foundation/Foundation.h>

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

NS_ENUM(long long, TUSRangeBytes) {TUSInvalidRange = -1};

@class TUSData;
@protocol TUSResumableUploadDelegate;

@interface TUSResumableUpload : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (assign) id<TUSResumableUploadDelegate> delegate;
@property (readwrite, copy) TUSUploadResultBlock resultBlock;
@property (readwrite, copy) TUSUploadFailureBlock failureBlock;
@property (readonly) float progress;

- (id)initWithURL:(NSString *)url
              data:(TUSData *)data
       fingerprint:(NSString *)fingerprint;
- (void) start;

- (TUSRange)rangeFromHeader:(NSString*)rangeHeader;
@end

@protocol TUSResumableUploadDelegate <NSObject>
@optional
- (void)upload:(TUSResumableUpload*)upload willBeginUploadToURL:(NSURL*)url;
- (void)upload:(TUSResumableUpload*)upload didFinishUploadToURL:(NSURL*)url;
- (void)upload:(TUSResumableUpload*)upload didFailWithError:(NSError*)error;
@end
