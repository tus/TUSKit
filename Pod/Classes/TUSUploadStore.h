//
//  TUSUploadStore.h
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import <Foundation/Foundation.h>
#import "TUSResumableUpload.h"

@interface TUSUploadStore : NSObject

@property (nonatomic, strong) NSMutableDictionary *backgroundUploadStore;
@property (nonatomic, strong) NSMutableDictionary *uploadTaskStore;

-(BOOL) saveDictionaryForUpload:(NSString *)uploadId dictionary:(NSDictionary *)data;
-(NSDictionary *) loadDictionaryForUpload:(NSString *)uploadId;
-(NSString *) loadBackgroundUploadId:(NSUInteger)uploadTaskId;
-(BOOL)saveTaskId:(NSUInteger)backgroundTaskId withBackgroundUploadId:(NSString *)backgroundUploadId;
-(BOOL) removeUploadTask:(NSUInteger)uploadTaskId;
-(BOOL) removeUpload:(NSString *)uploadId;
-(NSArray *)allUploadIds;
-(BOOL) containsUploadId:(NSString *)uploadId;

@end
