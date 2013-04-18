//
//  TusAppDelegate.h
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TUSDemoViewController;

@interface TusAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) TUSDemoViewController *viewController;

@end
