//
//  TUSUploadStore.m
//  Pods
//
//  Created by Jay Rogers on 5/20/16.
//
//

#import "TUSUploadStore.h"
#import "TUSResumableUpload2.h"

@implementation TUSUploadStore

-(id) init
{
    self = [super init];
    if (self) {
        self.backgroundUploadStore = [NSMutableDictionary new];
        self.uploadTaskStore = [NSMutableDictionary new];
    }
    return self;
}

-(BOOL)saveDictionaryForUpload:(NSString *)uploadId dictionary:(NSDictionary *)data;
{
    [self.backgroundUploadStore setObject:data forKey:uploadId];
    
    return YES;
}

-(BOOL)saveTaskId:(NSUInteger)backgroundTaskId withBackgroundUploadId:(NSString *)backgroundUploadId
{
    [self.uploadTaskStore setObject:backgroundUploadId forKey:@(backgroundTaskId)];
    
    return YES;
}

- (NSString *)loadBackgroundUploadId:(NSUInteger)backgroundTaskId
{
    return [self.uploadTaskStore objectForKey:@(backgroundTaskId)];
}

-(NSDictionary *)loadDictionaryForUpload:(NSString *)uploadId
{
    return [self.backgroundUploadStore objectForKey:uploadId];
}

-(BOOL)removeUploadTask:(NSUInteger)uploadTaskId
{
    [self.uploadTaskStore removeObjectForKey:@(uploadTaskId)];
    
    return YES;
}

-(BOOL)removeBackgroundUpload:(NSString *)uploadId
{
    [self.backgroundUploadStore removeObjectForKey:uploadId];

    return YES;
}

-(NSMutableArray *)loadAllBackgroundIds
{
    NSMutableArray *backgroundUploadIds = [NSMutableArray new];
    
    for (id backgroundUploadId in self.backgroundUploadStore) {
        [backgroundUploadIds addObject:backgroundUploadId];
    }
    
    return backgroundUploadIds;
}


@end
