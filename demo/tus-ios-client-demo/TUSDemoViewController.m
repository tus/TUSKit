//
//  TUSDemoViewController.m
//  tus-ios-client-demo
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

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
    [self.imageOverlay setHidden:YES];
    [self.progressBar setProgress:.0];
    NSString* text = [NSString stringWithFormat:NSLocalizedString(@"for upload to:\n%@",nil), [self endpoint]];
    [self.urlTextView setText:text];
}

#pragma mark - IBAction Methods
- (IBAction)chooseFile:(id)sender
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imagePicker.sourceType];
    imagePicker.delegate = self;
    [self.urlTextView setText:nil];
    [self.imageView setImage:nil];
    [self.progressBar setProgress:.0];
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - UIImagePickerDelegate Methods
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 NSString* type = [info valueForKey:UIImagePickerControllerMediaType];
                                 CFStringRef typeDescription = (UTTypeCopyDescription((__bridge CFStringRef)(type)));
                                 NSString* text = [NSString stringWithFormat:NSLocalizedString(@"Uploading %@…", nil), typeDescription];
                                 CFRelease(typeDescription);
                                 [self.statusLabel setText:text];
                                 [self.imageOverlay setHidden:NO];
                                 [self.chooseFileButton setEnabled:NO];
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
                              self.imageView.image = [UIImage imageWithCGImage:[asset thumbnail]];
                              self.imageView.alpha = .5;
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
        [self.chooseFileButton setEnabled:YES];
        NSString* text = self.urlTextView.text;
        text = [text stringByAppendingFormat:@"\n%@", [error localizedDescription]];
        [self.urlTextView setText:text];
        [self.statusLabel setText:NSLocalizedString(@"Failed!", nil)];
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
                                   message:[error localizedDescription]
                                   delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil] show];
    };
}

- (void(^)(NSURL* url))resultBlock
{
    return ^(NSURL* url) {
        NSLog(@"File uploaded to: %@", url);
        [self.chooseFileButton setEnabled:YES];
        [self.imageOverlay setHidden:YES];
        self.imageView.alpha = 1;
    };
}

- (NSString*)endpoint
{
    return @"http://master.tus.io/files";
}

@end
