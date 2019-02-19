//
//  TKViewController.m
//  TUSKit
//
//  Created by Michael Avila on 08/10/2014.
//  Copyright (c) 2014 Michael Avila. All rights reserved.
//
//  Additions and changes for TUSSession implementation by Findyr
//  Copyright (c) 2016 Findyr

#import "TKViewController.h"

#import <TUSKit/TUSKit.h>
#import <Photos/Photos.h>


static NSString* const UPLOAD_ENDPOINT = @"https://master.tus.io/files/";
static NSString* const FILE_NAME = @"tuskit_example";

@interface TKViewController ()

@property (strong, nonatomic) TUSSession *tusSession;

@end

static TUSUploadProgressBlock progressBlock = ^(int64_t bytesWritten, int64_t bytesTotal){
    // Update your progress bar here
    NSLog(@"progress: %llu / %llu", (unsigned long long)bytesWritten, (unsigned long long)bytesTotal);
};

static TUSUploadResultBlock resultBlock = ^(NSURL* fileURL){
    // Use the upload url
    NSLog(@"url: %@", fileURL);
};

static TUSUploadFailureBlock failureBlock = ^(NSError* error){
    // Handle the error
    NSLog(@"error: %@", error);
};

@implementation TKViewController

-(void)viewDidLoad
{
    NSURL * applicationSupportURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    
    TUSUploadStore * uploadStore = [[TUSFileUploadStore alloc] initWithURL:[applicationSupportURL URLByAppendingPathComponent:FILE_NAME]];
    self.tusSession = [[TUSSession alloc] initWithEndpoint:[[NSURL alloc] initWithString:UPLOAD_ENDPOINT] dataStore:uploadStore allowsCellularAccess:YES];
    for (TUSResumableUpload * upload in [self.tusSession restoreAllUploads]){
        upload.progressBlock = progressBlock;
        upload.resultBlock = resultBlock;
        upload.failureBlock = failureBlock;
    }
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
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if(status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            [self presentViewController:imagePicker animated:YES completion:nil];
        }];
    } else if (status == PHAuthorizationStatusAuthorized) {
        [self presentViewController:imagePicker animated:YES completion:nil];
    } else if (status == PHAuthorizationStatusRestricted) {
        //Permisions Needed
    } else if (status == PHAuthorizationStatusDenied) {
        // Permisions Needed
    }

}



- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    //MARK: Grabbing data from the ImagePicker using the PhotosLibray
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                     subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary
                                                                     options:nil];
    PHAssetCollection *assetCollection = result.firstObject;
    NSLog(@"%@", assetCollection.localizedTitle);
    
    NSArray<NSURL *> *array = [[NSArray alloc] initWithObjects:assetUrl, nil];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:array options:nil];
    PHAsset *asset = [fetchResult firstObject];
    
    [[[PHImageManager alloc] init] requestImageDataForAsset:asset options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        
        NSURL *documentDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSAllDomainsMask][0];
        NSURL *fileUrl = [documentDirectory URLByAppendingPathComponent:[[NSUUID alloc] init].UUIDString];
        NSError *error;
        if (![imageData writeToURL:fileUrl options:NSDataWritingAtomic error:&error]) {
            NSLog(@"%li", (long)error.code);
        }
        
                // If a file has not been created yet by your TUS backend
                TUSResumableUpload *upload = [self.tusSession createUploadFromFile:fileUrl headers:@{} metadata:@{}];
        
                upload.progressBlock = progressBlock;
                upload.resultBlock = resultBlock;
                upload.failureBlock = failureBlock;
        
                [upload resume];
                
//                //If a file has been created by your TUS backend, and you simply need to upload the data
//                NSURL *urlForAlreadyCreatedFile = [[NSURL alloc] initWithString:@"URL_HERE"];
//                TUSResumableUpload *uploadToAleadyCreatedFile = [self.tusSession createUploadFromFile:fileUrl headers:@{} metadata:@{} uploadUrl:urlForAlreadyCreatedFile ];
//
//                uploadToAleadyCreatedFile.progressBlock = progressBlock;
//                uploadToAleadyCreatedFile.resultBlock = resultBlock;
//                uploadToAleadyCreatedFile.failureBlock = failureBlock;
//
//                [uploadToAleadyCreatedFile resume];
        
            }];
}




@end
