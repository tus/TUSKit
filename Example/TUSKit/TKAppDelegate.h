//
//  TKAppDelegate.h
//  TUSKit
//
//  Created by CocoaPods on 08/10/2014.
//  Copyright (c) 2014 Michael Avila. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TUSSession.h"

@interface TKAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) TUSSession *session;


@end
