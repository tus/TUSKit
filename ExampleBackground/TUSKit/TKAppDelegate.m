//
//  TKAppDelegate.m
//  TUSKit
//
//  Created by CocoaPods on 08/10/2014.
//  Copyright (c) 2014 Michael Avila. All rights reserved.
//

#import "TKAppDelegate.h"
#import "TUSBackgroundSession.h"

static NSString* const UPLOAD_ENDPOINT = @"http://127.0.0.1:1080/files/";

@implementation TKAppDelegate

//- (void) applicationDidBecomeActive:(UIApplication *)application
//{
//    NSURL *endpoint = [[NSURL alloc] initWithString:UPLOAD_ENDPOINT];
//    TUSBackgroundSession *backgroundSession = [[TUSBackgroundSession alloc] initWithEndpoint:endpoint allowsCellularAccess:YES];
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
//            TUSBackgroundUpload *backgroundUpload = [self.session getStore];
//        }
//        
//        for (int i=0; i < [uploadTasks count]; i++) {
//            TUSBackgroundUpload *backgroundUpload = [uploadTask[i] ]
//        }
//    }];
//}

@end
