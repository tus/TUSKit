//
//  TUSData.h
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.


#import <Foundation/Foundation.h>

@interface TUSData : NSObject <NSStreamDelegate>

@property (readwrite,copy) void (^failureBlock)(NSError* error);
@property (readwrite,copy) void (^successBlock)(void);
@property (readonly) NSInputStream* dataStream;

- (id)initWithData:(NSData*)data;

- (long long)length;
- (void)stop;
- (void)setOffset:(long long)offset;
- (BOOL)open; // Re-open a closed TUSData object if it can be. Return YES if the TUSData object is open after the call.
- (void)close; // Close this TUSData object if it can be

- (NSData*)dataChunk:(long long)chunkSize;

- (NSData*)dataChunk:(long long)chunkSize
          fromOffset: (NSUInteger)offset;

@end
