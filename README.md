# TUSKit

[![Protocol](http://img.shields.io/badge/tus_protocol-v1.0.0-blue.svg?style=flat)](http://tus.io/protocols/resumable-upload.html)
[![Version](https://img.shields.io/cocoapods/v/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![License](https://img.shields.io/cocoapods/l/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![Platform](https://img.shields.io/cocoapods/p/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)

From [tus.io](http://tus.io):

  Users want to share more and more photos and videos. But mobile networks are fragile. Platform APIs are a mess. Every project builds its own file uploader. A thousand one week projects that barely work, when all we need is one real project, done right.

  We are going to do this right. We will solve reliable file uploads for once and for all. A new open protocol for resumable uploads built on HTTP. Simple, cheap, reusable stacks for clients and servers. Any language, any platform, any network.

TUSKit is a ready to use tus client for iOS.

## tus 1.0 UPDATE
We are now tus 1.0 compatabile! 

Other updates:
Two new initialization parameteres.

an NSDictionary called 'uploadheaders' which allows for easy HTTP Header passing in case your API requries additional headers.
an NSString called 'filename' which allows to change the filename of the upload to the server instead of the old default 'video.mp4'



## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

To test the example project you will need to point the app to a tus friendly server. You can find
a list of [tus implementations online](http://tus.io/implementations.html). The example project is
configured to point to http://127.0.0.1:8080/files. You can change this on line 14 of TKViewController.m

    static NSString* const UPLOAD_ENDPOINT = @"http://127.0.0.1:1080/files";

You will, of course, need an example file to upload. I like videos cause they cover a few cases. You can find
[sample videos from Apple on online](http://support.apple.com/kb/HT1425). Grab the .mov file.

## Installation

TUSKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "TUSKit"

## License

TUSKit is available under the MIT license. See the LICENSE file for more info.

