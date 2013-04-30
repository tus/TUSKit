//
//  TUSDemoViewController.h
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TUSResumableUploadDelegate;

@interface TUSDemoViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, TUSResumableUploadDelegate>

@property (strong,nonatomic) IBOutlet UIButton* chooseFileButton;
@property (strong,nonatomic) IBOutlet UIProgressView* progressBar;
@property (strong,nonatomic) IBOutlet UILabel* statusLabel;
@property (strong,nonatomic) IBOutlet UITextView* urlTextView;
@property (strong,nonatomic) IBOutlet UIImageView* imageView;
@property (strong,nonatomic) IBOutlet UIView* imageOverlay;

- (IBAction)chooseFile:(id)sender;
@end
