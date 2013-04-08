//
//  Tus.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TusUpload.h"

typedef enum {
    CheckingFile,
    CreatingFile,
    UploadingFile,
} UploadState;

@interface TusUpload ()
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSURL *endpoint;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *fingerprint;
@property (strong, nonatomic) NSUserDefaults *localStorage;
@property (nonatomic) NSInteger offset;
@property (nonatomic) UploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@end

@implementation TusUpload

// @TODO This is not going to work for very large files as we need a way to stream data from disk without loading it all into memory
- (id) initWithEndpoint:(NSString *)url data:(NSData *)data fingerprint:(NSString *)fingerprint progress:(void (^)(NSInteger bytesWritten, NSInteger bytesTotal))progress {
    [self setEndpoint:[NSURL URLWithString:url]];
    [self setData:data];
    [self setProgress:progress];
    [self setFingerprint:fingerprint];
    [self setLocalStorage:[NSUserDefaults standardUserDefaults]];
    return self;
}

- (void) start{
    NSString *myUrl = [[self localStorage] valueForKey:[self fingerprint]];

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
    
    NSUInteger size = [[self data] length];
    NSInteger offset = [self offset];
    NSString *contentRange = [NSString stringWithFormat:@"bytes %d-%d/%d",offset,size-1,size];
    NSLog(@"Content-Range: %@", contentRange);
    NSDictionary *headers = @{ @"Content-Range": contentRange} ;
    
    NSData *data = [[self data] subdataWithRange:NSMakeRange(offset, size - offset)];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:data];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch([self state]) {
        case CheckingFile: {
            NSString *range = [headers valueForKey:@"Range"];
            NSLog(@"range: %@", range);
            if (range != nil) {
                NSArray *parts = [range componentsSeparatedByString:@"bytes="];
                if ([parts count] == 2) {
                    NSArray *bytes = [(NSString *)[parts objectAtIndex:1] componentsSeparatedByString:@"-"];
                    if ([bytes count] >= 2) {
                        NSInteger offset = [(NSString *)[bytes objectAtIndex:1] integerValue];
                        [self setOffset:offset];
                    }
                }
            }
            [self uploadFile];
            break;
        }
        case CreatingFile: {
            NSString *location = [headers valueForKey:@"Location"];
            [self setUrl:[NSURL URLWithString:location]];
            [[self localStorage] setValue:location forKey:[self fingerprint]];
            [[self localStorage] synchronize];            
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
            if ([self progress] != nil) {
                [self progress](totalBytesWritten+[self offset], totalBytesExpectedToWrite+[self offset]);
            }
            break;
        default:
            break;
    }

}

@end
