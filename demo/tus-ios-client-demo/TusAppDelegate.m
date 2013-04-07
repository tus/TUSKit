//
//  TusAppDelegate.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TusAppDelegate.h"

@interface TusAppDelegate()
    @property (strong, nonatomic) UIViewController *controller;
@end

@implementation TusAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIViewController *rootController = [[UIViewController alloc] init];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = rootController;
    [self.window addSubview:rootController.view];
    
    self.window.backgroundColor = [UIColor whiteColor];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button addTarget:self action:@selector(myButtonWasPressed) forControlEvents:UIControlEventTouchDown];
    [button setTitle:@"Select File" forState:UIControlStateNormal];

    float width = 200.0;
    float height = 40.0;
    button.frame = CGRectMake(self.window.screen.bounds.size.width / 2 - width / 2, self.window.screen.bounds.size.height / 2 - height / 2, width, height);
    [rootController.view addSubview:button];

    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void) myButtonWasPressed {
    UIImagePickerController *controller = [[UIImagePickerController alloc] init];
    [self.window.rootViewController presentViewController:controller animated:YES completion:nil];
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
