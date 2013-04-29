//
//  TUSDemoSettingsViewController.h
//  tus-ios-client-demo
//
//  Created by afh on 29-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import <UIKit/UIKit.h>

#define TUSRemoteURLDefaultsKey @"TUSRemoteURL"

@interface TUSDemoSettingsViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITextField* remoteURLField;

- (IBAction)flipUI:(id)sender;

@end
