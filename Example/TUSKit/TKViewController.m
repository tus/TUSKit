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

static NSString* const UPLOAD_ENDPOINT = @"http://192.168.5.80:1080/files/";
static NSString* const FILE_NAME = @"tuskit_example";

@interface TKViewController ()

@property (strong,nonatomic) ALAssetsLibrary *assetLibrary;
@property (strong, nonatomic) TUSSession *tusSession;

@end

@implementation TKViewController

-(void)viewDidLoad
{
    NSURL * applicationSupportURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    
    TUSUploadStore * uploadStore = [[TUSFileUploadStore alloc] initWithURL:[applicationSupportURL URLByAppendingPathComponent:FILE_NAME]];
    self.tusSession = [[TUSSession alloc] initWithEndpoint:[[NSURL alloc] initWithString:UPLOAD_ENDPOINT] dataStore:uploadStore allowsCellularAccess:YES];
    [self.tusSession restoreAllUploads];
    [self.tusSession resumeAll];
}

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

        
        ALAssetRepresentation *rep = [asset defaultRepresentation];
        Byte *buffer = (Byte*)malloc(rep.size);
        NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
        
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
        NSURL *documentDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSAllDomainsMask][0];
        NSURL *fileUrl = [documentDirectory URLByAppendingPathComponent:[[NSUUID alloc] init].UUIDString];
        
        NSError *error;
        if (![data writeToURL:fileUrl options:NSDataWritingAtomic error:&error]) {
            NSLog(@"%li", (long)error.code);
        }
        
        
        // Initiate the background transfer
        TUSResumableUpload *upload = [self.tusSession createUploadFromFile:fileUrl headers:@{} metadata:@{}];
        
        upload.progressBlock = ^(int64_t bytesWritten, int64_t bytesTotal){
           // Update your progress bar here
           NSLog(@"progress: %llu / %llu", (unsigned long long)bytesWritten, (unsigned long long)bytesTotal);
        };

        upload.resultBlock = ^(NSURL* fileURL){
           // Use the upload url
           NSLog(@"url: %@", fileURL);
        };

        upload.failureBlock = ^(NSError* error){
           // Handle the error
           NSLog(@"error: %@", error);
        };

        [upload resume];
    } failureBlock:^(NSError* error) {
        NSLog(@"Unable to load asset due to: %@", error);
    }];
}

@end
