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

@property (nonatomic, strong) NSMutableDictionary *backgroundUploadStore;
@property (nonatomic, strong) NSMutableDictionary *uploadTaskStore;

-(BOOL) saveDictionaryForUpload:(NSString *)uploadId dictionary:(NSDictionary *)data;
-(NSDictionary *) loadDictionaryForUpload:(NSString *)uploadId;
-(NSString *) loadBackgroundUploadId:(NSUInteger)uploadTaskId;
-(BOOL) saveBackgroundTaskId:(NSUInteger)backgroundTaskId backgroundUploadId:(NSString *)backgroundUploadId;
-(BOOL) removeUploadTaskId:(NSUInteger)uploadTaskId;
-(BOOL) removeBackgroundUpload:(NSString *)uploadId;
-(NSMutableArray *)loadAllBackgroundIds;

@end
