//
//  Tus.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TusUpload.h"

@interface TusUpload ()
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSURL *endpoint;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@end

//void (^simpleBlock)(void);

@implementation TusUpload

- (id) initWithEndpoint:(NSString *)url data:(NSData *)data progress:(void (^)(NSInteger bytesSent, NSInteger bytesTotal))progress {
    [self setEndpoint:[NSURL URLWithString:url]];
    [self setData:data];
    [self setProgress:progress];
    return self;
}

- (void) start{
    [self createUpload];
}

- (void) createUpload{
    NSUInteger size = [[self data] length];
    NSDictionary *headers = @{ @"Content-Range": [NSString stringWithFormat:@"bytes */%d",size]} ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void) uploadData{
    NSUInteger size = [[self data] length];
    NSDictionary *headers = @{ @"Content-Range": [NSString stringWithFormat:@"bytes 0-%d/%d",size-1,size]} ;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:[self data]];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLConnection *connection __unused = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (bool) isFirstRequest {
    return [self url] == nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    if ([self isFirstRequest]) {
        NSString *location = [[httpResponse allHeaderFields] valueForKey:@"Location"];
        [self setUrl:[NSURL URLWithString:location]];
        [self uploadData];
        return;
    }
    
    NSLog(@"response: %@", [httpResponse allHeaderFields]);
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if ([self isFirstRequest]) {
        return;
    }
    
    if ([self progress] == nil) {
        return;
        
    }
    [self progress](totalBytesWritten, totalBytesExpectedToWrite);    
}

@end
