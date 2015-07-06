//
//  TUSKit.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
/*
 Compatibility for tus.io 1.0 developed by HotPoint Social App
 */

#ifndef TUSKit_h
#define TUSKit_h

@import Foundation;

#define TUS_LOGGING_ENABLED 1
#if TUS_LOGGING_ENABLED
#define TUSLog( s, ... ) NSLog( @"<%@:(%d)> %@", \
[[NSString stringWithUTF8String:__FILE__] lastPathComponent], \
__LINE__, \
[NSString stringWithFormat:(s), ##__VA_ARGS__])
#else
#define TUSLog( s, ... ) ;
#endif

#import "TUSData.h"
#import "TUSAssetData.h"
#import "TUSResumableUpload.h"

#endif
