//
//  TUSAssetData.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.




#import "TUSData.h"

#if TARGET_OS_IPHONE
#import <AssetsLibrary/AssetsLibrary.h>
#elif defined TARGET_OS_OSX
@import MediaLibrary;
#endif
__deprecated_msg("TUSAssetData is no longer in use as of TUSKit 1.4.0")
@interface TUSAssetData : TUSData

#if TARGET_OS_IPHONE
- (id)initWithAsset:(ALAsset*)asset;
#elif defined TARGET_OS_OSX
- (id)initWithAsset:(MLMediaObject*)asset;
#endif

@end
