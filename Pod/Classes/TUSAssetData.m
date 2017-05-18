//
//  TUSAssetData.m
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.

#import "TUSKit.h"
#import "TUSAssetData.h"

@interface TUSAssetData ()
#if TARGET_OS_IPHONE
@property (strong, nonatomic) ALAsset* asset;
#elif defined TARGET_OS_OSX
@property (strong, nonatomic) MLMediaObject* asset;
#endif
@end

@implementation TUSAssetData

#if TARGET_OS_IPHONE
- (id)initWithAsset:(ALAsset*)asset
{
    self = [super init];
    if (self) {
        self.asset = asset;
    }
    return self;
}
#endif
#if TARGET_OS_OSX
- (id)initWithAsset:(MLMediaObject*)asset
{
    self = [super init];
    if (self) {
        self.asset = asset;
    }
    return self;
}
#endif



#pragma mark - TUSData Methods
#if TARGET_OS_IPHONE
- (long long)length
{
    ALAssetRepresentation* assetRepresentation = [_asset defaultRepresentation];
    if (!assetRepresentation) {
        // NOTE:
        // defaultRepresentation "returns nil for assets from a shared photo
        // stream that are not yet available locally." (ALAsset Class Reference)

        // TODO:
        // Handle deferred availability of ALAssetRepresentation,
        // by registering for an ALAssetsLibraryChangedNotification.
        TUSLog(@"@TODO: Implement support for ALAssetsLibraryChangedNotification to support shared photo stream assets");
        return 0;
    }

    return [assetRepresentation size];
}
#endif
#if TARGET_OS_OSX
- (long long)length
{
    if (!_asset) {
        // NOTE:
        // defaultRepresentation "returns nil for assets from a shared photo
        // stream that are not yet available locally." (ALAsset Class Reference)
        
        // TODO:
        // Handle deferred availability of ALAssetRepresentation,
        // by registering for an ALAssetsLibraryChangedNotification.
        TUSLog(@"@TODO: Implement support for ALAssetsLibraryChangedNotification to support shared photo stream assets");
        return 0;
    }
    
    return [_asset fileSize];
}
#endif

#if TARGET_OS_IPHONE
- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(long long)offset
                length:(NSUInteger)length
                 error:(NSError **)error
{
    ALAssetRepresentation* assetRepresentation = [_asset defaultRepresentation];
    return [assetRepresentation getBytes:buffer
                              fromOffset:offset
                                  length:length
                                   error:error];
}
#endif
#if TARGET_OS_OSX
#endif


@end
