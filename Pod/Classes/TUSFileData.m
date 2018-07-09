//
//  TUSFileData.m
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import "TUSFileData.h"
#import "TUSErrors.h"

@interface TUSFileData(){
    long long _length;
}
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSNumber *savedLength;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic) BOOL closed;
@end

@implementation TUSFileData
-(instancetype)initWithFileURL:(NSURL *)url
{
    // Check file first
    if (![[NSFileManager defaultManager] isReadableFileAtPath:url.filePathURL]  ){
        return nil;
    }
    
    self = [super init];
    if (self){
        self.fileURL = url;
        _length = -1;
    }
    return self;
}

-(long long)length
{
    if (_length < 0){
        NSNumber *newLength = nil;
        if ([self.fileURL getResourceValue:&newLength forKey:NSURLFileSizeKey error:nil]){
            _length = newLength.longLongValue;
        } else {
            NSLog(@"Error fetching length for file %@", self.fileURL);
        }
    }
    return _length;
    
}

- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(NSUInteger)offset
                length:(NSUInteger)length
                 error:(NSError **)error
{
    @synchronized (self) {
        if (self.closed){
            if (error){
                *error = [[NSError alloc] initWithDomain:TUSErrorDomain code:TUSFileDataErrorClosed userInfo:nil];
            }
            return 0;
        } else if (![self open]){ // Only call "open" if it is not closed, to prevent automatic re-opening.
            if (error){
                *error = [[NSError alloc] initWithDomain:TUSErrorDomain code:TUSFileDataErrorCannotOpen userInfo:nil];
            }
            return 0;
        }
        
        [self.fileHandle seekToFileOffset:offset];
        NSData *readData = [self.fileHandle readDataOfLength:length];
        [readData getBytes:buffer length:length]; // readData has at most 'length' bytes because we did readDataOfLength above. Therefore all bytes are copied.
        return readData.length; // As all bytes from readData are copied into the buffer, this is always correct.
    }
    
}

-(void)close
{
    @synchronized (self) {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        self.closed = YES;
    }
}
    
-(BOOL)open
{
    @synchronized (self) {
        if (!self.fileHandle){
            NSError *internalError;
            self.fileHandle = [NSFileHandle fileHandleForReadingFromURL:self.fileURL error:&internalError];
            if (internalError){
                return NO;
            }
        }
        self.closed = NO;
        return YES;
    }
    
}

- (NSData*)dataChunk:(long long)chunkSize
          fromOffset: (NSUInteger)offset
{
    [self.fileHandle seekToFileOffset:offset];
    NSData *chunkData = [self.fileHandle readDataOfLength:chunkSize];
    return chunkData;
}
@end
