//
//  TUSBackgroundSession.m
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import "TUSBackgroundSession.h"

@implementation TUSBackgroundSession

- (id)initWithEndpoint:(NSURL *)endpoint
            supports3G:(BOOL)supports3G
{
    self = [super init];
    
    if (self) {
        NSString *identifier = [[NSString alloc] initWithString:@"TUSProtocol:" stringByAppendingString:endpoint];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        self.endpoint = endpoint;
        self.supports3G = _supports3G;
    }
    
    return self;
}

@end
