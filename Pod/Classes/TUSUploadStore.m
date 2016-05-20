//
//  TUSUploadStore.m
//  Pods
//
//  Created by Jay Rogers on 5/20/16.
//
//

#import "TUSUploadStore.h"

@implementation TUSUploadStore

-(id) init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

-(BOOL)saveDictionaryForUpload:(NSString *)uploadId dictionary:(NSDictionary *)data;
{
    [self.dataStore setObject:data forKey:uploadId];
    
    return YES;
}

-(NSDictionary *)loadDictionaryForUpload:(NSString *)uploadId
{
    return [self.dataStore objectForKey:uploadId];
}

@end
