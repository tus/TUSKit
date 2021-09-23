# TUSKit

An iOS client written in `Swift` for [tus resumable upload protocol](http://tus.io/).

[![Protocol](http://img.shields.io/badge/tus_protocol-v1.0.0-blue.svg?style=flat)](http://tus.io/protocols/resumable-upload.html)
[![Version](https://img.shields.io/cocoapods/v/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/cocoapods/l/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![Platform](https://img.shields.io/cocoapods/p/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit**


With this client, you can upload regular raw `Data` or filepaths. 
Please refer to the documentation inside `TUSClient` for details.

## Usage

Here is how you can instantiate a `TUSClient` instance.

Be sure to store a reference to the client somewhere. Then initialize as you normally would.
``` swift
final class MyClass {
  let tusClient: TUSClient
  
  init() {
        tusClient = TUSClient(config: TUSConfig(server: URL(string: "https://tusd.tusdemo.net/files")!), sessionIdentifier: "TUS DEMO", storageDirectory: URL(string: "TUS")!)
        tusClient.delegate = self
  }
}
```

Note that you can register as a delegate to retrieve the URL's of the uploads, and also any errors that may arise.

You can conform to the `TUSClientDelegate`


```swift
extension MyClass: TUSClientDelegate {
    func didStartUpload(id: UUID, client: TUSClient) {
        print("TUSClient started upload, id is \(id)")
        print("TUSClient remaining is \(client.remainingUploads)")
    }
    
    func didFinishUpload(id: UUID, url: URL, client: TUSClient) {
        print("TUSClient finished upload, id is \(id) url is \(url)")
        print("TUSClient remaining is \(client.remainingUploads)")
        if client.remainingUploads == 0 {
            print("Finished uploading")
        }
    }
    
    func uploadFailed(id: UUID, error: Error, client: TUSClient) {
        print("TUSClient upload failed for \(id) error \(error)")
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        print("TUSClient File error \(error)")
    }
}
```


### Starting an upload

A `TUSClient` can upload `Data` or paths to a file in the form of a `URL`.

To upload data, use the `upload(data:)` method`

```swift
let data = Data("I am some data".utf8)
let uploadId = client.upload(data: data)
```

To upload multiple data files at once, use the `uploadMultiple(dataFiles:)` method.

To upload a single stored file, retrieve a file path and pass it to the client.

```swift
let pathToFile:URL = ...
let uploadId = tusClient.uploadFileAt(filePath: pathToFile)
```

To upload multiple files at once, you can use the `uploadFiles(filePaths:)` method.

## Measuring upload progress

To know how many files have yet to be uploaded, please refer to the `remainingUploads` property.

Please note that there isn't a percentage supplied, since it's up to you to define what the starting point is of an upload.
For example. If you upload 10 files, and 3 are finished, then you are at 3/10. However, if during this upload you add 2 more, should that count as 3/12 or do you consider it a a fresh upload? So 0/9. It's up to you to define how finished uploads are counted when adding new uploads.


## Upload id's

By starting an upload you will receive an id. This id is passed to you to the `TUSClientDelegate` for reference.
You can use this id to identify which files are finished or failed. You can also delete these files on failure if you want.

## Parallelism 

At the time of writing, this client does not support TUS' concatenation option. 
It does, however, support parallel uploads in a single client. It does also support multiple clients.

## Mechanics

The `TUSClient` will retry a failed upload a few times before reporting it as an error.

The `TUSClient` will try to limit to max 5 concurrent files per upload.

The `TUSClient` will try to upload a file fully, and if it gets interrupted (e.g. broken connection or app is killed), it will continue where it left of.

The `TUSClient` stored files locally to upload them. It will use the `storageDirectory` path that is passed in the initializer.

The `TUSClient` will automatically removed locally stored files (internally) once their upload is complete.

## Multiple instances

`TUSClient` supports multiple instances for simultaneous unrelated uploads, if you so please. 

Warning: Multiple clients should not share the same `storageDirectory`. Give each client their own directory to work from, or bugs may ensure.

Please note that `TUSClient` since version 3.0.0 is *not* a singleton anymore. 

If you strongly feel you want a singleton, you can still make one using the static keyword.

```swift
final class MyClass {
  static let tusClient: TUSClient = ...
}
```

## Example app

Please refer to the example app inside this project to see how to add photos from a PHPicker, using SwiftUI. You can also use the `PHPicker` mechanic for UIKit.

