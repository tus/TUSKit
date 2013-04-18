//
//  TusAppDelegate.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import "TusAppDelegate.h"
#import "TUSData.h"
#import "TUSAssetData.h"
#import "TUSResumableUpload.h"

@interface TusAppDelegate()
    @property (strong, nonatomic) UIViewController *controller;
    @property (strong, nonatomic) ALAssetsLibrary* assetsLibrary;
@end

@implementation TusAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setAssetsLibrary:[[ALAssetsLibrary alloc] init]];
    UIViewController *rootController = [[UIViewController alloc] init];
    [self setWindow:[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]];
    [[self window] setRootViewController:rootController];
    [[self window] addSubview:[rootController view]];
    [[self window] setBackgroundColor:[UIColor whiteColor]];

    // Select File Button
    float buttonWidth = 200.0;
    float buttonHeight = 40.0;
    float buttonX = self.window.screen.bounds.size.width / 2 - buttonWidth / 2;
    float buttonY = self.window.screen.bounds.size.height / 2 - buttonHeight / 2;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button addTarget:self action:@selector(myButtonWasPressed) forControlEvents:UIControlEventTouchDown];
    [button setTitle:@"Select File" forState:UIControlStateNormal];
    [button setFrame:CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight)];
    [[rootController view] addSubview:button];

    // Progress Bar
    float progressWidth = self.window.screen.bounds.size.width * 0.8;
    float progressHeight = 20.0;
    float progressX = self.window.screen.bounds.size.width / 2 - progressWidth / 2;
    float progressY = buttonY + buttonHeight + 20.00;
    UIProgressView *progress = [[UIProgressView alloc] initWithFrame:(CGRectMake(progressX, progressY, progressWidth, progressHeight))];
    [[rootController view] addSubview:progress];
    [self setProgress:progress];

    [self.window makeKeyAndVisible];
    return YES;
}

- (void) myButtonWasPressed {
    UIImagePickerController *controller = [[UIImagePickerController alloc] init];
    [controller setDelegate:self];
    [self.window.rootViewController presentViewController:controller animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    [self uploadImageFromAsset:info];
}

- (void)uploadImageFromData:(NSDictionary*)info
{
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSString *fingerprint = [assetUrl absoluteString];
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    TUSData* uploadData = [[TUSData alloc] initWithData:imageData];
    TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithEndpoint:[self endpoint] data:uploadData fingerprint:fingerprint progress:[self progressBlock]];
    [upload start];
}

- (void)uploadImageFromAsset:(NSDictionary*)info
{
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSString *fingerprint = [assetUrl absoluteString];

    [[self assetsLibrary] assetForURL:assetUrl
                          resultBlock:^(ALAsset* asset) {
                              TUSAssetData* uploadData = [[TUSAssetData alloc] initWithAsset:asset];
                              TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithEndpoint:[self endpoint] data:uploadData fingerprint:fingerprint progress:[self progressBlock]];
                              [upload start];
                          }
                         failureBlock:^(NSError* error) {
                             NSLog(@"Unable to load asset due to: %@", error);
                         }];
}

- (void(^)(NSInteger, NSInteger))progressBlock
{
    return ^(NSInteger bytesWritten, NSInteger bytesTotal) {
        float progress = (float)bytesWritten / (float)bytesTotal;
        [self.progress setProgress:progress];
    };
}

- (NSString*)endpoint
{
    return @"http://master.tus.io/files";
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
