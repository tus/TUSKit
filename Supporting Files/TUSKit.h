//
//  TUSKit.h
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#define TUS_LOGGING_ENABLED 1
#if TUS_LOGGING_ENABLED
#define TUSLog( s, ... ) NSLog( @"<%@:(%d)> %@", \
[[NSString stringWithUTF8String:__FILE__] lastPathComponent], \
__LINE__, \
[NSString stringWithFormat:(s), ##__VA_ARGS__])
#else
#define TUSLog( s, ... ) ;
#endif

#import "TUSAssetData.h"
#import "TUSData.h"
#import "TUSErrors.h"
#import "TUSFileData.h"
#import "TUSFileUploadStore.h"
#import "TUSResumableUpload.h"
#import "TUSSession.h"
#import "TUSUploadStore.h"

//! Project version number for TUSKit.
FOUNDATION_EXPORT double TUSKitVersionNumber;

//! Project version string for TUSKit.
FOUNDATION_EXPORT const unsigned char TUSKitVersionString[];
