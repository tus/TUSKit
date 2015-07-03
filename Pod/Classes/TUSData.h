//
//  TUSData.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
/*
 Compatibility for tus.io 1.0 developed by HotPoint Social App
 */

@import Foundation;

@interface TUSData : NSObject <NSStreamDelegate>

@property (readwrite,copy) void (^failureBlock)(NSError *error);
@property (readwrite,copy) void (^successBlock)(void);

- (id)initWithData:(NSData *)data;
- (NSInputStream *)dataStream;
- (long long)length;
- (void)stop;

@end
