//
//  TKViewController.m
//  TUSKit
//
//  Created by Michael Avila on 08/10/2014.
//  Copyright (c) 2014 Michael Avila. All rights reserved.
//

#import "TKViewController.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <TUSKit/TUSKit.h>

static NSString* const UPLOAD_ENDPOINT = @"http://127.0.0.1:8080/files";

@interface TKViewController ()

@property (strong,nonatomic) ALAssetsLibrary *assetLibrary;

@end

@implementation TKViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self selectFile:nil];
}

- (IBAction)selectFile:(id)sender {
    UIImagePickerController *imagePicker = [UIImagePickerController new];
    imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imagePicker.sourceType];
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:nil];
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    
    if (!self.assetLibrary) {
        self.assetLibrary = [ALAssetsLibrary new];
    }
    
    [self.assetLibrary assetForURL:assetUrl resultBlock:^(ALAsset* asset) {
        NSString *fingerprint = [assetUrl absoluteString];
        NSDictionary *headers =  @{@"":@""};
        
        TUSAssetData *uploadData = [[TUSAssetData alloc] initWithAsset:asset];
        TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithURL:UPLOAD_ENDPOINT data:uploadData fingerprint:fingerprint uploadHeaders:headers fileName:@"video.mp4"];

        upload.progressBlock = ^(NSInteger bytesWritten, NSInteger bytesTotal){
           // Update your progress bar here
           NSLog(@"progress: %d / %d", bytesWritten, bytesTotal);
        };

        upload.resultBlock = ^(NSURL* fileURL){
           // Use the upload url
           NSLog(@"url: %@", fileURL);
        };

        upload.failureBlock = ^(NSError* error){
           // Handle the error
           NSLog(@"error: %@", error);
        };

        [upload start];
    } failureBlock:^(NSError* error) {
        NSLog(@"Unable to load asset due to: %@", error);
    }];
}

@end
