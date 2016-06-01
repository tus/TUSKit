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

// Serializing keys
const NSString *TEMP_URL_KEY = @"tempFileUrl";
const NSString *FILE_URL_KEY = @"fileUrl";
const NSString *FILE_OFFSET_KEY = @"offset";

// Temporary file subdirectory within Application Support
NSString * const TEMP_FILE_SUBDIRECTORY = @"TUSKit";

@interface TUSFileReader()

@property (strong, nonatomic) NSURL * fileUrl; // Nonatomic because it won't change once initialized
@property (strong, nonatomic) NSURL * tempFileUrl;
@property NSUInteger offset;

@end

@implementation TUSFileReader{
    long long _length; // Store the computed length of the file
}


// Designated Initializer
- (instancetype)initWithURL:(NSURL*)fileUrl
{
    self = [super init];
    if (self){
        self.fileUrl = fileUrl;
        _length = -1; // Set to -1 to force a load of the length from disk.
    }
    return self;
}

- (instancetype)initWithFileURL:(NSURL*)fileUrl
                    tempFileURL:(NSURL*)tempFileUrl
                         offset:(NSUInteger)offset
{
    self = [self initWithURL:fileUrl]; // Call the designated initializer
    if (self) {
        self.tempFileUrl = tempFileUrl;
        self.offset = offset;
    }
    return self;
}


+ (instancetype)deserializeFromDictionary:(NSDictionary *)dictionary
{
    // The URLs were saved as bookmarks, not as paths (because paths might change between launches)
    NSData *fileUrlData = dictionary[FILE_URL_KEY];
    NSObject *tempUrlData = dictionary[TEMP_URL_KEY];
    NSNumber *offset = dictionary[FILE_OFFSET_KEY];
    
    NSURL * fileUrl = [NSURL URLByResolvingBookmarkData:fileUrlData options:0 relativeToURL:nil bookmarkDataIsStale:nil error:nil];
    NSURL * tempUrl = tempUrlData == [NSNull null]? nil : [NSURL URLByResolvingBookmarkData:(NSData *)tempUrlData options:0 relativeToURL:nil bookmarkDataIsStale:nil error:nil];
    
    return [[self alloc] initWithFileURL:fileUrl tempFileURL:tempUrl offset:offset.unsignedIntegerValue];
}

- (NSURL *)getFileFromOffset:(NSUInteger)offset
                       error:(NSError **)error
{
    // Special cases
    // Offset is zero, so just return the file url itself
    if (offset == 0){
        return self.fileUrl;
    }
    
    // Offset is the current offset, so return the current tempFileUrl if a file exists there.
    if (offset == self.offset && [[NSFileManager defaultManager] fileExistsAtPath:self.tempFileUrl.path]){
        return self.tempFileUrl;
    }
    
    // Create a new file
    
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
    self.offset = offset; // Update our offset
    return self.tempFileUrl;
}

/**
 Get the temporary file path for this file
 */
- (NSURL *)tempFileUrl
{
    if (!_tempFileUrl){
        NSString *uuid = [[NSUUID alloc] init].UUIDString;
        NSURL *applicationSupport = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask][0];
        
        _tempFileUrl = [[applicationSupport URLByAppendingPathComponent:TEMP_FILE_SUBDIRECTORY isDirectory:YES] URLByAppendingPathComponent:uuid];
    }
    
    return _tempFileUrl;
}

/**
 Get the current length of the file.  Returns 0 if there is no file found.
 */
- (NSUInteger)length
{
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

- (NSDictionary *)serialize
{
    // We don't save length because it can be recomputed very easily
    NSObject *tempFileString = [self.tempFileUrl bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:nil] ?: [NSNull null];

    return @{
        TEMP_URL_KEY: tempFileString,
        FILE_URL_KEY: [self.fileUrl bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:nil],
        FILE_OFFSET_KEY: @(self.offset)
    };
}

- (BOOL)close
{
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
