//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TUSData.h"

#import "TUSResumableUpload.h"

typedef enum {
    CheckingFile,
    CreatingFile,
    UploadingFile,
} UploadState;

@interface TUSResumableUpload ()
@property (strong, nonatomic) TUSData *data;
@property (strong, nonatomic) NSURL *endpoint;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *fingerprint;
@property (strong, nonatomic) NSMutableDictionary *resumableUploads;
@property (nonatomic) long long offset;
@property (nonatomic) UploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@end

@implementation TUSResumableUpload

- (id) initWithEndpoint:(NSString *)url data:(TUSData *)data fingerprint:(NSString *)fingerprint
{
    self = [super init];
    if (self) {
        [self setEndpoint:[NSURL URLWithString:url]];
        [self setData:data];
        [self setFingerprint:fingerprint];

        NSURL* resumableUploadsPath = [self resumableUploadsFilePath];
        self.resumableUploads = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
        if (!self.resumableUploads) {
            self.resumableUploads = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

- (void) start{
    if (self.progressBlock) {
        self.progressBlock(0, 0);
    }
    NSString *myUrl = [self.resumableUploads valueForKey:[self fingerprint]];

    NSLog(@"fingerprint: %@", [self fingerprint]);
    if (myUrl == nil) {
        NSLog(@"no url found");
        [self createFile];
        return;
    }

    [self setUrl:[NSURL URLWithString:myUrl]];
    [self checkFile];
}

- (void) createFile{
    [self setState:CreatingFile];

    NSUInteger size = [[self data] length];
    NSDictionary *headers = @{ @"Content-Range": [NSString stringWithFormat:@"bytes */%d",size]} ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) checkFile{
    [self setState:CheckingFile];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"HEAD"];
    [request setHTTPShouldHandleCookies:NO];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) uploadFile{
    [self setState:UploadingFile];
    
    long long size = [[self data] length];
    long long offset = [self offset];
    NSString *contentRange = [NSString stringWithFormat:@"bytes %lld-%lld/%lld",
                              offset, size - 1, size];
    NSLog(@"Content-Range: %@", contentRange);
    NSDictionary *headers = @{ @"Content-Range": contentRange };

    __weak TUSResumableUpload* upload = self;
    self.data.failureBlock = ^(NSError* error) {
        if (upload.failureBlock) {
            upload.failureBlock(error);
        }
    };
    self.data.successBlock = ^() {
        [upload.resumableUploads removeObjectForKey:[upload fingerprint]];
        BOOL success = [upload.resumableUploads writeToURL:[upload resumableUploadsFilePath]
                                              atomically:YES];
        if (!success) {
            NSLog(@"Unable to save resumableUploads file");
        }
        if (upload.resultBlock) {
            upload.resultBlock(upload.url);
        }
    };
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBodyStream:[[self data] dataStream]];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}


#pragma mark - NSURLConnectionDelegate Protocol Delegate Methods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch([self state]) {
        case CheckingFile: {
            NSString *rangeHeader = [headers valueForKey:@"Range"];
            if (rangeHeader) {
                NSLog(@"range: %@", rangeHeader);
                TUSRange range = [self rangeFromHeader:rangeHeader];
                [self setOffset:range.first];
            }
            [self uploadFile];
            break;
        }
        case CreatingFile: {
            NSString *location = [headers valueForKey:@"Location"];
            [self setUrl:[NSURL URLWithString:location]];
            [self.resumableUploads setValue:location forKey:[self fingerprint]];
            BOOL success = [self.resumableUploads writeToURL:[self resumableUploadsFilePath]
                                    atomically:YES];
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

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {

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
    TUSRange range = TUSMakeRange(NSNotFound, 0);
    NSLog(@"range: %@", rangeHeader);
    NSArray *parts = [rangeHeader componentsSeparatedByString:@"bytes="];
    if ([parts count] == 2) {
        NSArray *bytes = [(NSString *)[parts objectAtIndex:1] componentsSeparatedByString:@"-"];
        if ([bytes count] >= 2) {
            NSUInteger start = [(NSString *)[bytes objectAtIndex:0] integerValue];
            NSUInteger end = [(NSString *)[bytes objectAtIndex:1] integerValue];
            range = TUSMakeRange(start, end);
        }
    }
    return range;
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
