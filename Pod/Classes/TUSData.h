//
//  TUSData.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.

#import <Foundation/Foundation.h>

@interface TUSData : NSObject <NSStreamDelegate>

@property (readwrite,copy) void (^failureBlock)(NSError* error);
@property (readwrite,copy) void (^successBlock)(void);

- (id)initWithData:(NSData*)data;
- (NSInputStream*)dataStream;
- (long long)length;
- (void)stop;

@end
