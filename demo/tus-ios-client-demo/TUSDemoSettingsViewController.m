//
//  TUSDemoSettingsViewController.m
//  tus-ios-client-demo
//
//  Created by afh on 29-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import "TUSDemoViewController.h"
#import "TUSDemoSettingsViewController.h"

@interface TUSDemoSettingsViewController ()

@end

@implementation TUSDemoSettingsViewController

- (void)viewDidLoad
{
    self.remoteURLField.text = [[NSUserDefaults standardUserDefaults] valueForKey:TUSRemoteURLDefaultsKey];
    [self.remoteURLField becomeFirstResponder];
}

#pragma mark - IBActions
- (IBAction)flipUI:(id)sender
{
    NSURL* remoteURL = [NSURL URLWithString:_remoteURLField.text];
    if (!(remoteURL && [[remoteURL scheme] hasPrefix:@"http"])) {
        _remoteURLField.textColor = [UIColor redColor];
        return;
    }

    [[NSUserDefaults standardUserDefaults] setValue:_remoteURLField.text
                                             forKey:TUSRemoteURLDefaultsKey];
    [_remoteURLField resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate Methods
- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    _remoteURLField.textColor = [UIColor blackColor];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self flipUI:self];
    return YES;
}

@end
