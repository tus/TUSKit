//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TUSData.h"

#import "TUSResumableUpload.h"

#define HTTP_PUT @"PUT"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_RANGE @"Range"
#define HTTP_LOCATION @"Location"
#define HTTP_CONTENT_RANGE @"Content-Range"
#define HTTP_BYTES_UNIT @"bytes"
#define HTTP_RANGE_EQUAL @"="
#define HTTP_RANGE_DASH @"-"
#define REQUEST_TIMEOUT 30

typedef NS_ENUM(NSInteger, TUSUploadState) {
    Idle,
    CheckingFile,
    CreatingFile,
    UploadingFile,
};

@interface TUSResumableUpload ()
@property (strong, nonatomic) TUSData *data;
@property (strong, nonatomic) NSURL *endpoint;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *fingerprint;
@property (nonatomic) long long offset;
@property (nonatomic) TUSUploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@end

@implementation TUSResumableUpload

- (id)initWithURL:(NSString *)url
             data:(TUSData *)data
      fingerprint:(NSString *)fingerprint
{
    self = [super init];
    if (self) {
        [self setEndpoint:[NSURL URLWithString:url]];
        [self setData:data];
        [self setFingerprint:fingerprint];
    }
    return self;
}

- (void) start
{
    if (self.progressBlock) {
        self.progressBlock(0, 0);
    }

    NSString *uploadUrl = [[self resumableUploads] valueForKey:[self fingerprint]];
    if (uploadUrl == nil) {
        NSLog(@"No resumable upload URL for fingerprint %@", [self fingerprint]);
        [self createFile];
        return;
    }

    [self setUrl:[NSURL URLWithString:uploadUrl]];
    [self checkFile];
}

- (void) createFile
{
    [self setState:CreatingFile];

    NSUInteger size = [[self data] length];
    NSDictionary *headers = @{ HTTP_CONTENT_RANGE: [self contentRangeWithSize:size] } ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) checkFile
{
    [self setState:CheckingFile];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) uploadFile
{
    [self setState:UploadingFile];
    
    long long size = [[self data] length];
    long long offset = [self offset];
    NSString *contentRange = [self contentRangeFrom:offset to:size-1 size:size];
    NSDictionary *headers = @{ HTTP_CONTENT_RANGE: contentRange };

    __weak TUSResumableUpload* upload = self;
    self.data.failureBlock = ^(NSError* error) {
        NSLog(@"Failed to upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        if (upload.failureBlock) {
            upload.failureBlock(error);
        }
    };
    self.data.successBlock = ^() {
        [upload setState:Idle];
        NSLog(@"Finished upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        NSMutableDictionary* resumableUploads = [upload resumableUploads];
        [resumableUploads removeObjectForKey:[upload fingerprint]];
        BOOL success = [resumableUploads writeToURL:[upload resumableUploadsFilePath]
                                         atomically:YES];
        if (!success) {
            NSLog(@"Unable to save resumableUploads file");
        }
        if (upload.resultBlock) {
            upload.resultBlock(upload.url);
        }
    };

    NSLog(@"Resuming upload at %@ for fingerprint %@ from offset %lld (%@)",
          [self url], [self fingerprint], offset, contentRange);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PUT];
    [request setHTTPBodyStream:[[self data] dataStream]];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark - NSURLConnectionDelegate Protocol Delegate Methods
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    NSLog(@"ERROR: connection did fail due to: %@", error);
    [connection cancel];
    [[self data] stop];
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}

#pragma mark - NSURLConnectionDataDelegate Protocol Delegate Methods

// TODO: Add support to re-initialize dataStream
- (NSInputStream *)connection:(NSURLConnection *)connection
            needNewBodyStream:(NSURLRequest *)request
{
    NSLog(@"ERROR: connection requested new body stream, which is currently not supported");
    return nil;
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch([self state]) {
        case CheckingFile: {
            NSString *rangeHeader = [headers valueForKey:HTTP_RANGE];
            if (rangeHeader) {
                TUSRange range = [self rangeFromHeader:rangeHeader];
                [self setOffset:range.last];
                NSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
                      [self url], [self fingerprint], [self offset], rangeHeader);
            }
            else {
                NSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
            }
            [self uploadFile];
            break;
        }
        case CreatingFile: {
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            [self setUrl:[NSURL URLWithString:location]];
            NSLog(@"Created resumable upload at %@ for fingerprint %@",
                  [self url], [self fingerprint]);
            NSURL* fileURL = [self resumableUploadsFilePath];
            NSMutableDictionary* resumableUploads = [self resumableUploads];
            [resumableUploads setValue:location forKey:[self fingerprint]];
            BOOL success = [resumableUploads writeToURL:fileURL atomically:YES];
            if (!success) {
                NSLog(@"Unable to save resumableUploads file");
            }
            [self uploadFile];
            break;
        }
        default:
            break;
    }
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    switch([self state]) {
        case UploadingFile:
            if (self.progressBlock) {
                self.progressBlock(totalBytesWritten+[self offset], [[self data] length]+[self offset]);
            }
            break;
        default:
            break;
    }

}


#pragma mark - Private Methods
- (TUSRange)rangeFromHeader:(NSString*)rangeHeader
{
    long long first = TUSInvalidRange;
    long long last = TUSInvalidRange;

    NSString* bytesPrefix = [HTTP_BYTES_UNIT stringByAppendingString:HTTP_RANGE_EQUAL];
    NSScanner* rangeScanner = [NSScanner scannerWithString:rangeHeader];
    BOOL success = [rangeScanner scanUpToString:bytesPrefix intoString:NULL];
    if (!success) {
        NSLog(@"Failed to scan up to '%@' from '%@'", bytesPrefix, rangeHeader);
    }

    success = [rangeScanner scanString:bytesPrefix intoString:NULL];
    if (!success) {
        NSLog(@"Failed to scan '%@' from '%@'", bytesPrefix, rangeHeader);
    }

    success = [rangeScanner scanLongLong:&first];
    if (!success) {
        NSLog(@"Failed to first byte from '%@'", rangeHeader);
    }

    success = [rangeScanner scanString:HTTP_RANGE_DASH intoString:NULL];
    if (!success) {
        NSLog(@"Failed to byte-range separator from '%@'", rangeHeader);
    }

    success = [rangeScanner scanLongLong:&last];
    if (!success) {
        NSLog(@"Failed to last byte from '%@'", rangeHeader);
    }

    if (first > last) {
        first = TUSInvalidRange;
        last = TUSInvalidRange;
    }
    if (first < 0) {
        first = TUSInvalidRange;
    }
    if (last < 0) {
        last = TUSInvalidRange;
    }

    return TUSMakeRange(first, last);
}

- (NSString*)contentRangeFrom:(long long)first to:(long long)last size:(long long)size
{
    return [NSString stringWithFormat:@"%@ %lld-%lld/%lld", HTTP_BYTES_UNIT, first, last, size];
}

- (NSString*)contentRangeWithSize:(long long)size
{
    return [NSString stringWithFormat:@"%@ */%lld", HTTP_BYTES_UNIT, size];
}

- (NSMutableDictionary*)resumableUploads
{
    static id resumableUploads = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL* resumableUploadsPath = [self resumableUploadsFilePath];
        resumableUploads = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
        if (!resumableUploads) {
            resumableUploads = [[NSMutableDictionary alloc] init];
        }
    });

    return resumableUploads;
}

- (NSURL*)resumableUploadsFilePath
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray* directories = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                               inDomains:NSUserDomainMask];
    NSURL* applicationSupportDirectoryURL = [directories lastObject];
    NSString* applicationSupportDirectoryPath = [applicationSupportDirectoryURL absoluteString];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:applicationSupportDirectoryPath
                           isDirectory:&isDirectory]) {
        NSError* error = nil;
        BOOL success = [fileManager createDirectoryAtURL:applicationSupportDirectoryURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
        if (!success) {
            NSLog(@"Unable to create %@ directory due to: %@",
                  applicationSupportDirectoryURL,
                  error);
        }
    }
    return [applicationSupportDirectoryURL URLByAppendingPathComponent:@"TUSResumableUploads.plist"];
}

@end
