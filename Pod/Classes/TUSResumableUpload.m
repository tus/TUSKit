//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.

#import "TUSKit.h"
#import "TUSData.h"

#import "TUSResumableUpload.h"

#define HTTP_PATCH @"PATCH"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_OFFSET @"Upload-Offset"
#define HTTP_UPLOAD_LENGTH  @"Upload-Length"
#define HTTP_TUS @"Tus-Resumable"
#define HTTP_TUS_VERSION @"1.0.0"

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
@property (nonatomic, strong) NSDictionary *uploadHeaders;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation TUSResumableUpload
@synthesize backgroundTask;

- (id)initWithURL:(NSString *)url
             data:(TUSData *)data
      fingerprint:(NSString *)fingerprint
    uploadHeaders:(NSDictionary *)headers
         fileName:(NSString *)fileName

{
    self = [super init];
    if (self) {
        [self setEndpoint:[NSURL URLWithString:url]];
        [self setData:data];
        [self setFingerprint:fingerprint];
        [self setUploadHeaders:headers];
        [self setFileName:fileName];
        [self setQueue:[[NSOperationQueue alloc] init]];
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
    
    NSUInteger size = (NSUInteger)[[self data] length];
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lu", (unsigned long)size] forKey:HTTP_UPLOAD_LENGTH];
    
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    NSString *plainString = _fileName;
    NSMutableString *fileName = [[NSMutableString alloc] initWithString:@"filename "];
    NSData *plainData = [plainString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [plainData base64EncodedStringWithOptions:0];
    
    [mutableHeader setObject:[fileName stringByAppendingString:base64String] forKey:@"Upload-Metadata"];
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:FALSE];
    [connection setDelegateQueue:self.queue];
    [connection start];
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [connection cancel];
    }];
}

- (void) checkFile
{
    [self setState:CheckingFile];
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:FALSE];
    [connection setDelegateQueue:self.queue];
    [connection start];
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [connection cancel];
    }];
}

- (void) uploadFile
{
    [self setState:UploadingFile];
    
    long long offset = [self offset];
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", offset] forKey:HTTP_OFFSET];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    [mutableHeader setObject:@"application/offset+octet-stream" forKey:@"Content-Type"];
    
    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    __weak TUSResumableUpload *upload = self;
    self.data.failureBlock = ^(NSError *error) {
        TUSLog(@"Failed to upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        if (upload.failureBlock) {
            upload.failureBlock(error);
        }
    };
    __weak typeof(self) weakSelf = self;
    self.data.successBlock = ^() {
        
        [upload setState:Idle];
        
        TUSLog(@"Finished upload to %@ for fingerprint %@", [upload url], [upload fingerprint]);
        [[UIApplication sharedApplication] endBackgroundTask:weakSelf.backgroundTask];
        NSMutableDictionary *resumableUploads = [upload resumableUploads];
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
    
    
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:FALSE];
    [connection setDelegateQueue:self.queue];
    [connection start];
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [connection cancel];
    }];
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
    [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
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
            if ([httpResponse statusCode] < 200 || [httpResponse statusCode] > 204) {
                TUSLog(@"Server responded with %ld. Restarting upload",
                       (long)httpResponse.statusCode);
                [self createFile];
                return;
            }
            NSString *rangeHeader = [headers valueForKey:HTTP_OFFSET];
            if (rangeHeader) {
                long long size = [rangeHeader longLongValue];
                if (size >= [[self data] length]) {
                    
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
            
            TUSLog(@"Created resumable upload at %@ for fingerprint %@", [self url], [self fingerprint]);
            
            NSURL *fileURL = [self resumableUploadsFilePath];
            
            NSMutableDictionary *resumableUploads = [self resumableUploads];
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
                self.progressBlock(totalBytesWritten + (NSUInteger)[self offset], (NSUInteger)[[self data] length]+(NSUInteger)[self offset]);
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
        NSURL *resumableUploadsPath = [self resumableUploadsFilePath];
        resumableUploads = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
        if (!resumableUploads) {
            resumableUploads = [[NSMutableDictionary alloc] init];
        }
    });
    
    return resumableUploads;
}

- (NSURL *)resumableUploadsFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directories = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                               inDomains:NSUserDomainMask];
    NSURL *applicationSupportDirectoryURL = [directories lastObject];
    NSString *applicationSupportDirectoryPath = [applicationSupportDirectoryURL absoluteString];
    
    BOOL isDirectory = NO;
    
    if (![fileManager fileExistsAtPath:applicationSupportDirectoryPath
                           isDirectory:&isDirectory]) {
        NSError *error = nil;
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
