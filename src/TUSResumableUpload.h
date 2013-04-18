//
//  TUSResumableUpload.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <Foundation/Foundation.h>


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
- (id) initWithEndpoint:(NSString *)url data:(TUSData *)data fingerprint:(NSString *)fingerprint progress:(void (^)(NSInteger bytesWritten, NSInteger bytesTotal))progress;
- (void) start;

- (TUSRange)rangeFromHeader:(NSString*)rangeHeader;
@end