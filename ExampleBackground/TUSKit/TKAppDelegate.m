//
//  TKAppDelegate.m
//  TUSKit
//
//  Created by CocoaPods on 08/10/2014.
//  Copyright (c) 2014 Michael Avila. All rights reserved.
//

#import "TKAppDelegate.h"
#import "TUSSession.h"


@implementation TKAppDelegate

//- (void) applicationDidBecomeActive:(UIApplication *)application
//{
//    NSURL *endpoint = [[NSURL alloc] initWithString:UPLOAD_ENDPOINT];
//    TUSSession *backgroundSession = [[TUSSession alloc] initWithEndpoint:endpoint allowsCellularAccess:YES];
//    
//    self.session = backgroundSession;
//}
//
//- (void) applicationDidEnterBackground:(UIApplication *)application
//{
//    NSLog(@"in background");
//}
//
//- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
//{
//    NSLog(@"completed");
//}
//
//- (void) applicationWillTerminate
//{
//    //Save all uploads to disk
//    
//    //Get all upload tasks, find the background uploads associated with them, persist to disk
//    NSURLSession *existingSession = [self.session getSession];
//    
//    [existingSession getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
//        
//        // For each of the tasks, get the associated background task, and persist it to disk
//        for (int i=0; i < [dataTasks count]; i++) {
//            TUSResumableUpload *backgroundUpload = [self.session getStore];
//        }
//        
//        for (int i=0; i < [uploadTasks count]; i++) {
//            TUSResumableUpload *backgroundUpload = [uploadTask[i] ]
//        }
//    }];
//}

@end
