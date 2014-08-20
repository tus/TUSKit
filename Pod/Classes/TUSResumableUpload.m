//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TUSKit.h"
#import "TUSData.h"

#import "TUSResumableUpload.h"

#define HTTP_PATCH @"PATCH"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_OFFSET @"Offset"
#define HTTP_FINAL_LENGTH @"Final-Length"
#define HTTP_LOCATION @"Location"
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
        TUSLog(@"No resumable upload URL for fingerprint %@", [self fingerprint]);
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
    NSDictionary *headers = @{ HTTP_FINAL_LENGTH: [NSString stringWithFormat:@"%u", size] } ;
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
    
    long long offset = [self offset];
    NSDictionary *headers = @{ HTTP_OFFSET: [NSString stringWithFormat:@"%lld", offset],
                               @"Content-Type": @"application/offset+octet-stream"};

    __weak TUSResumableUpload* upload = self;
    self.data.failureBlock = ^(NSError* error) {
        TUSLog(@"Failed to upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        if (upload.failureBlock) {
            upload.failureBlock(error);
        }
    };
    self.data.successBlock = ^() {
        [upload setState:Idle];
        TUSLog(@"Finished upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        NSMutableDictionary* resumableUploads = [upload resumableUploads];
        [resumableUploads removeObjectForKey:[upload fingerprint]];
        BOOL success = [resumableUploads writeToURL:[upload resumableUploadsFilePath]
                                         atomically:YES];
        if (!success) {
            TUSLog(@"Unable to save resumableUploads file");
        }
        if (upload.resultBlock) {
            upload.resultBlock(upload.url);
        }
    };

    TUSLog(@"Resuming upload at %@ for fingerprint %@ from offset %lld",
          [self url], [self fingerprint], offset);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PATCH];
    [request setHTTPBodyStream:[[self data] dataStream]];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark - NSURLConnectionDelegate Protocol Delegate Methods
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    TUSLog(@"ERROR: connection did fail due to: %@", error);
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
    TUSLog(@"ERROR: connection requested new body stream, which is currently not supported");
    return nil;
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch([self state]) {
        case CheckingFile: {
            if (httpResponse.statusCode != 200) {
                NSLog(@"Server responded with %d. Restarting upload",
                      httpResponse.statusCode);
                [self createFile];
                return;
            }
            NSString *rangeHeader = [headers valueForKey:HTTP_OFFSET];
            if (rangeHeader) {
                long long size = [rangeHeader longLongValue];
                if (size >= [self offset]) {
                  //TODO: we skip file upload, but we mightly verifiy that file?
                  [self setState:Idle];
                  TUSLog(@"Skipped upload to %@ for fingerprint %@", [self url], [self fingerprint]);
                  NSMutableDictionary* resumableUploads = [self resumableUploads];
                  [resumableUploads removeObjectForKey:[self fingerprint]];
                  BOOL success = [resumableUploads writeToURL:[self resumableUploadsFilePath]
                                                   atomically:YES];
                  if (!success) {
                    TUSLog(@"Unable to save resumableUploads file");
                  }
                  if (self.resultBlock) {
                    self.resultBlock(self.url);
                  }
                  break;
                } else {
                  [self setOffset:size];
                }
                TUSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
                      [self url], [self fingerprint], [self offset], rangeHeader);
            }
            else {
                TUSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
            }
            [self uploadFile];
            break;
        }
        case CreatingFile: {
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            [self setUrl:[NSURL URLWithString:location]];
            TUSLog(@"Created resumable upload at %@ for fingerprint %@",
                  [self url], [self fingerprint]);
            NSURL* fileURL = [self resumableUploadsFilePath];
            NSMutableDictionary* resumableUploads = [self resumableUploads];
            [resumableUploads setValue:location forKey:[self fingerprint]];
            BOOL success = [resumableUploads writeToURL:fileURL atomically:YES];
            if (!success) {
                TUSLog(@"Unable to save resumableUploads file");
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
            TUSLog(@"Unable to create %@ directory due to: %@",
                  applicationSupportDirectoryURL,
                  error);
        }
    }
    return [applicationSupportDirectoryURL URLByAppendingPathComponent:@"TUSResumableUploads.plist"];
}

@end
