//
//  TUSDemoViewController.m
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import <TUSKit/TUSKit.h>
#import "TUSDemoViewController.h"

@interface TUSDemoViewController ()
    @property (strong, nonatomic) ALAssetsLibrary* assetsLibrary;
@end

@implementation TUSDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.assetsLibrary = [[ALAssetsLibrary alloc] init];
    [self.progressBar setHidden:YES];
    [self.progressBar setProgress:.0];
    [self.statusLabel setHidden:YES];
    [self.urlTextView setHidden:YES];
}

#pragma mark - IBAction Methods
- (IBAction)chooseFile:(id)sender
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imagePicker.sourceType];
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - UIImagePickerDelegate Methods
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 [self.statusLabel setText:NSLocalizedString(@"Uploading…",nil)];
                                 [self.statusLabel setHidden:NO];
                                 [self.chooseFileButton setEnabled:NO];
                                 [self.progressBar setHidden:NO];
                                 [self uploadImageFromAsset:info];
                             }];
}

#pragma mark - Private Methods
- (void)uploadImageFromData:(NSDictionary*)info
{
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSString *fingerprint = [assetUrl absoluteString];
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    TUSData* uploadData = [[TUSData alloc] initWithData:imageData];
    TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithURL:[self endpoint] data:uploadData fingerprint:fingerprint];
    upload.progressBlock = [self progressBlock];
    upload.resultBlock = [self resultBlock];
    upload.failureBlock = [self failureBlock];
    [upload start];
}

- (void)uploadImageFromAsset:(NSDictionary*)info
{
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSString *fingerprint = [assetUrl absoluteString];

    [[self assetsLibrary] assetForURL:assetUrl
                          resultBlock:^(ALAsset* asset) {
                              TUSAssetData* uploadData = [[TUSAssetData alloc] initWithAsset:asset];
                              TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithURL:[self endpoint] data:uploadData fingerprint:fingerprint];
                              upload.progressBlock = [self progressBlock];
                              upload.resultBlock = [self resultBlock];
                              upload.failureBlock = [self failureBlock];
                              [upload start];
                          }
                         failureBlock:^(NSError* error) {
                             NSLog(@"Unable to load asset due to: %@", error);
                         }];
}

- (void(^)(NSInteger bytesWritten, NSInteger bytesTotal))progressBlock
{
    return ^(NSInteger bytesWritten, NSInteger bytesTotal) {
        float progress = (float)bytesWritten / (float)bytesTotal;
        if (isnan(progress)) {
            progress = .0;
        }
        [self.progressBar setProgress:progress];
    };
}

- (void(^)(NSError* error))failureBlock
{
    return ^(NSError* error) {
        NSLog(@"Failed to upload image due to: %@", error);
    };
}

- (void(^)(NSURL* url))resultBlock
{
    return ^(NSURL* url) {
        NSLog(@"File uploaded to: %@", url);
        [self.chooseFileButton setEnabled:YES];
        [self.progressBar setHidden:YES];
        [self.statusLabel setText:NSLocalizedString(@"Uploaded to:",nil)];
        [self.urlTextView setText:[url absoluteString]];
        [self.urlTextView setHidden:NO];
    };
}

- (NSString*)endpoint
{
    return @"http://master.tus.io/files";
}

@end
