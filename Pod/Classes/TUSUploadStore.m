//
//  TUSUploadStore.m
//  Pods
//
//  Created by Jay Rogers on 5/20/16.
//
//

#import "TUSUploadStore.h"
#import "TUSBackgroundUpload.h"

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

-(BOOL)saveBackgroundTaskId:(NSNumber *)backgroundTaskId withBackgroundUploadId:(NSString *)backgroundUploadId
{
    [self.dataStore setObject:backgroundUploadId forKey:backgroundTaskId];
    
    return YES;
}

-(BOOL)saveBackgroundUploadWithId:(TUSBackgroundUpload *)backgroundUpload
{
    [self.dataStore setObject:[backgroundUpload serializeObject] forKey:backgroundUpload.id];
    
    return YES;
}

- (NSString *)loadBackgroundUploadId:(NSNumber *)backgroundTaskId
{
    return [self.dataStore objectForKey:backgroundTaskId];
}

-(NSDictionary *)loadDictionaryForUpload:(NSString *)uploadId
{
    return [self.dataStore objectForKey:uploadId];
}


@end
