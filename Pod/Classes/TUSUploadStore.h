//
//  TUSUploadStore.h
//  Pods
//
//  Created by Jay Rogers on 5/20/16.
//
//

#import <Foundation/Foundation.h>
#import "TUSBackgroundUpload.h"

@interface TUSUploadStore : NSObject

@property (nonatomic, strong) NSMutableDictionary *dataStore;

-(BOOL) saveDictionaryForUpload:(NSString *)uploadId dictionary:(NSDictionary *)data;
-(NSDictionary *) loadDictionaryForUpload:(NSString *)uploadId;
-(NSString *)loadBackgroundUploadId:(NSNumber *)backgroundTaskId;
-(BOOL)saveBackgroundUploadWithId:(TUSBackgroundUpload *)backgroundUpload;
-(BOOL)saveBackgroundTaskId:(NSNumber *)backgroundTaskId withBackgroundUploadId:(NSString *)backgroundUploadId;

@end
