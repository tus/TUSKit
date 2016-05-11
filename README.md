# TUSKit
[![Protocol](http://img.shields.io/badge/tus_protocol-v1.0.0-blue.svg?style=flat)](http://tus.io/protocols/resumable-upload.html)
[![Version](https://img.shields.io/cocoapods/v/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![License](https://img.shields.io/cocoapods/l/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![Platform](https://img.shields.io/cocoapods/p/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)

An iOS client written in `Objective-C` for [tus resumable upload protocol](http://tus.io/).

## Installation

TUSKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "TUSKit"

## Example Project
To run the example project, clone the repo, and run `pod install` from the Example directory first. 

## The Protocol
You'll need a tus.io friendly server before using TUSKit or any other tus client. You can find a list of [tus implementations here](http://tus.io/implementations.html).

# Usage
------
## TUSAssetData
Each file you upload must be in the form of a `TUSAssetData` object. Create an `TUSAssetData` object by initializing with an `ALAsset` object.

    TUSAssetData *uploadData = [[TUSAssetData alloc] initWithAsset:asset];

## TUSResumableUpload
An upload can be created by initializing a `TUSResumableUpload` object. If your server requires specific headers for communication such as authentication, you may pass these headers on initialization.

    TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithURL:UPLOAD_ENDPOINT data:uploadData fingerprint:fingerprint uploadHeaders:headers fileName:@"video.mp4"];

**URL** - The URL to your tus.io server.

**data** - The `TUSAssetData` object you are uploading.

**fingerprint** - The absoulute path to the asset.

**uploadHeaders** - An `NSDictionary` of your custom headers for the upload.

**filename** - The filename...

## Upload Start
To start the upload process, run the `start` method on your `TUSResumableUpload` object.
  
    [upload start];


## progressBlock
A block to track progess on your upload. Here you can update your progress bar, print to the log, etc.

        upload.progressBlock = ^(NSInteger bytesWritten, NSInteger bytesTotal){
           NSLog(@"progress: %d / %d", bytesWritten, bytesTotal);
        };

## resultBlock
A block fired after a successful upload, returning the URL to your file on the server. Handle your success here!

        upload.resultBlock = ^(NSURL* fileURL){
           NSLog(@"url: %@", fileURL);
        };

## failureBlock
A block fired after a failed upload, returning the error. Handle your failure here!

        upload.failureBlock = ^(NSError* error){
           NSLog(@"error: %@", error);
        };


# Todo
------
- Carthage Support
- ~~Background Uploads~~

# About [tus.io](http://tus.io):
------
  Users want to share more and more photos and videos. But mobile networks are fragile. Platform APIs are a mess. Every project builds its own file uploader. A thousand one week projects that barely work, when all we need is one real project, done right.

  We are going to do this right. We will solve reliable file uploads for once and for all. A new open protocol for resumable uploads built on HTTP. Simple, cheap, reusable stacks for clients and servers. Any language, any platform, any network.

TUSKit is a ready to use tus client for iOS.


# License
------
TUSKit is available under the MIT license. See the LICENSE file for more info.

