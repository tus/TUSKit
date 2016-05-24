//
//  TUSBackgroundSession.h
//  Pods
//
//  Created by Jay Rogers on 5/23/16.
//
//

#import <Foundation/Foundation.h>
#import "TUSUploadStore.h"

@interface TUSBackgroundSession : NSObject

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *endpoint;
@property (nonatomic, strong) NSMutableArray *uploadTasks;
@property (nonatomic, strong) TUSUploadStore *store;
@property BOOL allowsCellularAccess;

- (instancetype) initWithEndpoint:(NSURL *)endpoint
             allowsCellularAccess:(BOOL)allowsCellularAccess

- (NSMutableArray *) addBackgroundUploadTasksToSession

- (TUSBackgroundUpload *)loadSavedBackgroundUpload:(NSNumber *)uploadTaskId
- (void) saveUploadTask:(NSURLSessionTask *)uploadTask
- (void) initiateBackgroundUpload:(NSURL *)fileUrl


@end
