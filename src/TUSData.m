//
//  TUSData.m
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import "TUSData.h"

#import "NSStream+BoundPair.h"

#import "TUSData.h"

#define TUS_BUFSIZE (64*1024)

@interface TUSData ()
@property (assign) long long offset;
@property (strong, nonatomic) NSInputStream* inputStream;
@property (strong, nonatomic) NSOutputStream* outputStream;
@property (strong, nonatomic) NSData* data;
@end

@implementation TUSData

- (id)init
{
    self = [super init];
    if (self) {
        NSInputStream* inStream = nil;
        NSOutputStream* outStream = nil;
        [NSStream createBoundInputStream:&inStream
                            outputStream:&outStream
                              bufferSize:TUS_BUFSIZE];
        assert(inStream != nil);
        assert(outStream != nil);
        self.inputStream = inStream;
        self.outputStream = outStream;
        self.outputStream.delegate = self;
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
    }
    return self;
}

- (id)initWithData:(NSData*)data
{
    self = [self init];
    if (self) {
        self.data = data;
    }
    return self;
}

#pragma mark - Public Methods
- (NSInputStream*)dataStream
{
    return _inputStream;
}

- (long long)length
{
    return _data.length;
}

- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(long long)offset
                length:(NSUInteger)length
                 error:(NSError **)error
{
    NSRange range = NSMakeRange(offset, length);
    if (offset + length > _data.length) {
        return 0;
    }

    [_data getBytes:buffer range:range];
    return length;
}


#pragma mark - NSStreamDelegate Protocol Methods
- (void)stream:(NSStream *)aStream
   handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            NSLog(@"TUSData stream opened");
        } break;
        case NSStreamEventHasSpaceAvailable: {
            uint8_t buffer[TUS_BUFSIZE];
            long long length = TUS_BUFSIZE;
            if (length > [self length] - [self offset]) {
                length = [self length] - [self offset];
            }
            if (!length) {
                [[self outputStream] setDelegate:nil];
                [[self outputStream] close];
                return;
            }
            NSLog(@"Reading %lld bytes from %lld to %lld until %lld"
                  , length, [self offset], [self offset] + length, [self length]);
            NSError* error = NULL;
            NSUInteger bytesRead = [self getBytes:buffer
                                       fromOffset:[self offset]
                                           length:length
                                            error:&error];
            if (!bytesRead) {
                NSLog(@"Unable to read bytes from asset due to: %@", error);
            } else {
                NSInteger bytesWritten = [[self outputStream] write:buffer
                                                        maxLength:bytesRead];
                NSLog(@"bytesWritten: %d", bytesWritten);
                if (bytesWritten <= 0) {
                    NSLog(@"Network write error %@", [aStream streamError]);
                } else {
                    [self setOffset:[self offset] + bytesWritten];
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            NSLog(@"TUSData stream error %@", [aStream streamError]);
        } break;
        case NSStreamEventHasBytesAvailable:
        case NSStreamEventEndEncountered:
        default:
            assert(NO);     // should never happen for the output stream
            break;
    }
}

@end

