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
#elif TARGET_OS_MAC
@import MediaLibrary;
#endif

@interface TUSAssetData : TUSData

#if TARGET_OS_IPHONE
- (id)initWithAsset:(ALAsset*)asset;
#elif TARGET_OS_MAC
- (id)initWithAsset:(MLMediaObject*)asset;
#endif

@end
