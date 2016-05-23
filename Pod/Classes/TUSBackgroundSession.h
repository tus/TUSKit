//
//  TUSBackgroundSession.h
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import <Foundation/Foundation.h>

@interface TUSBackgroundSession : NSObject

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *endpoint;
@property BOOL supports3G;

- (id) initWithEndpoint:(NSURL *)endpoint
             supports3G:(BOOL)supports3G

@end
