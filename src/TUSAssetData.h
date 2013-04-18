//
//  TUSAssetData.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import "TUSData.h"

@interface TUSAssetData : TUSData

- (id)initWithAsset:(ALAsset*)asset;

@end
