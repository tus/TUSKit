//
//  TUSFileReader.m
//  Pods
//
//  Created by Findyr on 5/18/16.
//
//

#import "TUSKit.h"
#import "TUSFileReader.h"
#define COPY_CHUNK_SIZE (10 * 1024 * 1024)

@interface TUSFileReader()
@property (strong, nonatomic) NSURL * fileUrl; // Nonatomic because it won't change once initialized
@property (strong, nonatomic) NSURL * tempFileUrl;
@end

@implementation TUSFileReader{
    long long _length;
}


- (instancetype)initWithFile:(NSURL*)fileUrl{
    self = [super init];
    if (self){
        self.fileUrl = fileUrl;
        _length = -1;
    }
    return self;
}

- (NSURL *)getFileFromOffset:(NSUInteger)offset
                       error:(NSError **)error{
    // TODO: How long will this take?
    NSError *fhError = nil;
    NSFileHandle *sourceFile = [NSFileHandle fileHandleForReadingFromURL:self.fileUrl error:&fhError];
    if (fhError){
        if (error){
            *error = fhError;
        }
        return nil;
    }
    
    NSFileHandle *targetFile = [NSFileHandle fileHandleForWritingToURL:self.tempFileUrl error:&fhError];
    if (fhError){
        if (error){
            *error = fhError;
        }
        return nil;
    }
    
    // Truncate target file.  We reuse the same temporary file.
    [targetFile truncateFileAtOffset:0];
    
    @try {
        // Read into target file
        [sourceFile seekToFileOffset:offset];
        for (NSData *copyChunk = [sourceFile readDataOfLength:COPY_CHUNK_SIZE]; copyChunk.length > 0; copyChunk = [sourceFile readDataOfLength:COPY_CHUNK_SIZE]){
            [targetFile writeData:copyChunk];
        }
    } @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:TUSFileReaderCopyError userInfo:@{@"message": [NSString stringWithFormat:@"Error copying file from path %@ to %@ from offset %llu", self.fileUrl, self.tempFileUrl, (unsigned long long)offset]}];
        return nil;
    }
    
    // Synchronize the target file we were writing.
    [targetFile synchronizeFile];
    return self.tempFileUrl;
}

/**
 Get the temporary file path for this file
 */
- (NSURL *)tempFileUrl{
    if (!_tempFileUrl){
        @throw @"Not implemented";
    }
    return _tempFileUrl;
}

/**
 Get the current length of the file.  Returns 0 if there is no file found.
 */
- (NSUInteger)length{
    // Attempt to get the file length
    if (_length < 0){
        NSNumber *fileLength = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.fileUrl.path error:nil] objectForKey:NSFileSize];
        if (fileLength){
            _length = fileLength.unsignedLongLongValue;
        }else {
            return 0;
        }
    }
    return (NSUInteger)_length; // Default to NO length if we can't find the file, the key, etc.
}

-(BOOL)close{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempFileUrl.path]){
        NSError * error = nil;
        BOOL returnValue = [[NSFileManager defaultManager] removeItemAtURL:self.tempFileUrl error:&error];
        if (!returnValue){
            TUSLog(@"Error deleting temporary file %@ for TUSFileReader wrapping %@", self.tempFileUrl, self.fileUrl);
        }
        return returnValue;
    }
    return YES;
}

@end
