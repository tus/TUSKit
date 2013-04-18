//
//  TUSResumableUpload.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TUSResumableUpload : NSObject
- (id) initWithEndpoint:(NSString *)url data:(NSData *)data fingerprint:(NSString *)fingerprint progress:(void (^)(NSInteger bytesWritten, NSInteger bytesTotal))progress;
- (void) start;
@end