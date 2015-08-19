//
//  TUSAssetData.m
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import "TusKit.h"
#import "TUSAssetData.h"

@interface TUSAssetData ()
@property (strong, nonatomic) ALAsset* asset;
@end

@implementation TUSAssetData

- (id)initWithAsset:(ALAsset*)asset
{
    self = [super init];
    if (self) {
        self.asset = asset;
    }
    return self;
}

#pragma mark - TUSData Methods
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

@end
