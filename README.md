# tus-ios-client

An iOS client implementing the [tus resumable upload
protocol](https://github.com/tus/tus-resumable-upload-protocol).

This first version will provide a low level API without a GUI. More advanced
features will follow.

## Adding tus-ios-client to your project

### As a framework

Clone the the latest version from Github:

```bash
$ git clone git://github.com/tus/tus-ios-client.git
```

* Drag and drop the `Frameworks/TUSKit.framework` folder insided the cloned
  repository onto your project name inside the project navigator
* Select "Copy items into destination group's folder (if needed)"
* Make sure your project is selected inside the "Add to targets" list
* Press "Finish"

### Via CocoaPads

to be written ...

### Via Copying

to be written ...

## UIImagePickerController Example

ExampleViewController.h:

```objc
#import <UIKit/UIKit.h>

@interface ExampleViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
- (IBAction)selectFile:(id)sender;
@end
```

ExampleViewController.m:

```obj
#import "ExampleViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <TUSKit/TUSKit.h>

@interface ExampleViewController ()
@property(strong,nonatomic) ALAssetsLibrary *assetLibrary;
@end

@implementation ExampleViewController

- (IBAction)selectFile:(id)sender
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imagePicker.sourceType];
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];

    if (!self.assetLibrary) {
        self.assetLibrary = [[ALAssetsLibrary alloc] init];
    }

    [self.assetLibrary assetForURL:assetUrl
                       resultBlock:^(ALAsset* asset) {
                           NSString *uploadUrl = @"http://master.tus.io/files";
                           NSString *fingerprint = [assetUrl absoluteString];
                           TUSAssetData* uploadData = [[TUSAssetData alloc] initWithAsset:asset];
                           TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithURL:uploadUrl data:uploadData fingerprint:fingerprint];
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
                       }
                      failureBlock:^(NSError* error) {
                          NSLog(@"Unable to load asset due to: %@", error);
                      }];
}

@end
```

## Building Framework

If you are hacking on the TUSKit framework itself and need to re-compile it,
here is how:

* Select TUSKit-Framework/iOS Device target
* Product -> Build For -> Archiving

## License

This project is licensed under the MIT license, see `LICENSE.txt`.
