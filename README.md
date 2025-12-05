# TUSKit

An iOS client written in `Swift` for [TUS resumable upload protocol](http://tus.io/).

[![Protocol](http://img.shields.io/badge/tus_protocol-v1.0.0-blue.svg?style=flat)](http://tus.io/protocols/resumable-upload.html)
[![Version](https://img.shields.io/cocoapods/v/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/cocoapods/l/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![Platform](https://img.shields.io/cocoapods/p/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)

With this client, you can upload regular raw `Data` or file-paths. 

## Usage

You can refer to the example project to see how TUSKit is implemented. 

As a starting point, please refer to the [SceneDelegate](TUSKitExample/TUSKitExample/SceneDelegate.swift).

Here is how you can instantiate a `TUSClient` instance.

Be sure to store a reference to the client somewhere. Then initialize as you normally would.
``` swift
final class MyClass {
  let tusClient: TUSClient
  
  init() {
      tusClient = TUSClient(server: URL(string: "https://tusd.tusdemo.net/files")!, sessionIdentifier: "TUS DEMO", storageDirectory: URL(string: "TUS")!)
      tusClient.delegate = self
  }
}
```

Note that you can register as a delegate to retrieve the URL's of the uploads, and also any errors that may arise.

Note that you *can* pass your own `URLSession` instance to the initializer.
However, custom `URLSession` instances with a background configuration are not supported, as `URLSessionTaskDelegate` cannot be assigned to tasks created by such sessions.

You can conform to the `TUSClientDelegate` to receive updates from the `TUSClient`.

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
    
    
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
    }
    
    
    func progressFor(id: UUID, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {

    }
    
}
```

### Starting an upload

A `TUSClient` can upload `Data` or paths to a file in the form of a `URL`.

To upload data, use the `upload(data:)` method`

```swift
let data = Data("I am some data".utf8)
let uploadId = try tusClient.upload(data: data)
```

To upload multiple data files at once, use the `uploadMultiple(dataFiles:)` method.

To upload a single stored file, retrieve a file path and pass it to the client.

```swift
let pathToFile:URL = ...
let uploadId = try tusClient.uploadFileAt(filePath: pathToFile)
```

To upload multiple files at once, you can use the `uploadFiles(filePaths:)` method.

## Custom upload URL and custom headers

To specify a custom upload URL (e.g. for TransloadIt) or custom headers to be added to a file upload, please refer to the `uploadURL` and `customHeaders` properties in the methods related to uploading. Such as: `upload`, `uploadFileAt`, `uploadFiles` or `uploadMultiple(dataFiles:)`.

### Custom header generation

Sometimes headers need to be signed or refreshed right before a request is sent.  
`TUSClient` exposes a header generation hook so you can mutate previously supplied custom headers without rebuilding the upload. Pass the optional `generateHeaders` closure to the initializer and TUSKit will call it before every `POST`, `PATCH`, or `HEAD` request.

```swift
let client = try TUSClient(
    server: serverURL,
    sessionIdentifier: "UploadSession",
    sessionConfiguration: configuration,
    storageDirectory: storageDirectory,
    supportedExtensions: [.creation]
) { uploadID, headers, onHeadersGenerated in
    tokenProvider.fetchToken(for: uploadID) { token in
        var mutatedHeaders = headers
        mutatedHeaders["Authorization"] = "Bearer \(token)"
        onHeadersGenerated(mutatedHeaders)
    }
}
```

TUSKit will reuse whatever headers you return for automatic retries or when resuming an upload, ensuring the same values are applied consistently. New headers can be introduced as needed, while core TUS headers such as `Upload-Offset` and `Content-Length` remain under the SDK’s control.

## Measuring upload progress

To know how many files have yet to be uploaded, please refer to the `remainingUploads` property.

Please note that there isn't a percentage supplied, since it's up to you to define what the starting point is of an upload.
For example. If you upload 10 files, and 3 are finished, then you are at 3/10. However, if during this upload you add 2 more, should that count as 3/12 or do you consider it a a fresh upload? So 0/9. It's up to you to define how finished uploads are counted when adding new uploads.

For byte level progress. Please implement the `TUSClientDelegate` protocol and set it as a the `delegate` property of `TUSClient`.

## Upload id's and contexts

By starting an upload you will receive an id. These id's are also passed to you via if you implement the `TUSClientDelegate`.
You can use these id's to identify which files are finished or failed (but you can also use contexts for that, see below). You can also delete these files on failure if you want. You can also use these id's to retry a failed upload.

Note that `TUSClient` will automatically retry an upload a few times, but will eventually give up, after which it will report an error. After which you can call the `retry` method and try again.

## Contexts

You can use id's to monitor progress and perform other tasks, such as stopping uploads. But you can also pass a context with richer information. TUSKit will return this context through various delegate calls. This way you don't have to keep track of the status of upload id's. You can pass in a small object with information, and you receive this from TUSKit.

Security notice: TUSKit will store this context on the disk next to other file metadata. This is to maintain the information between sessions.

## Starting a new session 

An upload can fail at any time. Even when an app is in the background.

Therefore, after starting a new app session, we recommend you inspect any failed uploads that may have occurred and act accordingly.
For instance, you can decide to do something with the failed uploads such as retrying them, deleting them, or reporting to the user.


```swift
For instance, here is how you can initialize the client and check its failed uploads. Note that we first fetch the id's, after which retry the uploads.
  
tusClient = TUSClient(server: URL(string: "https://tusd.tusdemo.net/files")!, sessionIdentifier: "TUS DEMO", storageDirectory: URL(string: "/TUS")!)
tusClient.delegate = self
tusClient.start()
        
do {
  // When starting, you can retrieve the locally stored uploads that are marked as failure, and handle those.
  // E.g. Maybe some uploads failed from a last session, or failed from a background upload.
  let ids = try tusClient.failedUploadIds()
  for id in ids {
    // You can either retry a failed upload...
    try tusClient.retry(id: id)
    // ...alternatively, you can delete them too
    // tusClient.removeCacheFor(id: id)
  }
} catch {
  // Could not fetch failed id's from disk
}

```

## Background uploading

When you incorporate background uploading, we strongly recommend you to inspect any failed uploads that may have occured in the background. Please refer to [Starting a new Session](#starting-a-new-session) for more information.

iOS can leverage a background URLSession to enable background uploads that continue when a user leaves your app or locks their device. For more information, take a look at Apple's docs on [background URLSession](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background). The docs focus on downloads but uploads follow pretty much the exact same principles.

To make incorporating background uploads as straightforward as possible, TUSKit handles all the complex details of managing the URLSession and delegate callbacks. As a consumer of TUSKit all you need to do is leverage the new initializer on `TUSClient` as shown below:

```swift
do {
    tusClient = try TUSClient(
        server: URL(string: "https://tusd.tusdemo.net/files")!,
        sessionIdentifier: "TUS DEMO",
        sessionConfiguration: .background(withIdentifier: "com.TUSKit.sample"),
        storageDirectory: URL(string: "/TUS")!,
        chunkSize: 0
    )
} catch {
    // ...
}
```

The easiest way to set everything up is to pass a `URLSession.background` configuration to the `TUSClient`. If you require a different configuration or don't want any background support at all, you're free to pass a different configuration.

Because TUSKit can now have uploads running while your app is no longer actively in memory, you should always use the `getStoredUpload` method on `TUSClient` on app launch to retrieve all stored uploads and extract information about which uploads are currently completed. Afterwards you can call `cleanup` to allow `TUSClient` to remove metadata for completed items. See the sample app for more details.

### Limitations and constraints for background uploads on iOS

The primary source for information on how background uploads work will always be [Apple's own documentation](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background) on performing network calls in the background. TUSKit is limited and bound by what's possible and allowed by the system.

In practice, this means that you should always schedule all of your uploads while the app is in the foreground. Scheduling more uploads while an app is in the background is not allowed and will result in the system deprioritizing your requests. 

For this reason, chunking is strongly discouraged when you intend to leverage background uploads since you would have to make several network calls, one after the other, to complete your upload.

It's also important to understand that iOS will automatically wait for your user to have a network connection before attempting to start your upload. This means your uploads might take a while to start. If a network connection drops _while_ an upload is in progress, iOS will attempt to re-upload your file automatically.

By default, iOS will retry the full upload instead of resuming where the upload has left off. Unfortunately we haven't found a way to prevent iOS from doing this. On iOS 17 Apple has adde support for resumable uploads. We're currently exploring how we can integrate TUSKit with this feature since both iOS and TUSKit rely on the same protocols.

### Warning: information below is deprecated in TUSKit 3.2.0.
Available from iOS13, you can schedule uploads to be performed in the background using the `scheduleBackgroundTasks()` method on `TUSClient`. 

Scheduled tasks are handled by iOS. Which means that each device will decide when it's best to upload in the background. Such as when it has a wifi connection and late at night.

As an example from the `SceneDelegate` found in the example app, you can schedule them accordingly:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // ... snip
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        tusClient.scheduleBackgroundTasks()
    }
}
```

## TUS Protocol Extensions
The client assumes by default that the server implements the [Creation TUS protocol extension](https://tus.io/protocols/resumable-upload.html#protocol-extensions). If your server does not support that, please ensure to provide an empty array for the `supportedExtensions` parameter in the client initializer.

## Example app

Please refer to the [example app](/TUSKitExample) inside this project to see how to add photos from a PHPicker, using SwiftUI. You can also use the `PHPicker` mechanic for UIKit.

## Parallelism 

At the time of writing, this client does not support TUS' concatenation option. 
It does, however, automatically support parallel uploads in a single client. It does also support multiple clients.

## Underlying Mechanics

The `TUSClient` will retry a failed upload two times (three total attempts) before reporting it as an error.

The `TUSClient` will try to upload a file fully, and if it gets interrupted (e.g. broken connection or app is killed), it will continue where it left of.

The `TUSClient` stores files locally to upload them. It will use the `storageDirectory` path that is passed in the initializer. Or create a default directory inside the documentsdir at /TUS .

The `TUSClient` will automatically removed locally stored files once their upload is complete.

## Multiple instances

`TUSClient` supports multiple instances for simultaneous unrelated uploads.

Warning: Multiple clients should not share the same `storageDirectory`. Give each client their own directory to work from, or bugs may occur.

Please note that `TUSClient` since version 3.0.0 is *not* a singleton anymore. 

If you strongly feel you want a singleton, you can still make one using the static keyword.

```swift
final class MyClass {
  static let tusClient: TUSClient = ...
}
```

But we discourage you from doing so because it makes resetting between tests harder, and it becomes problematic in a multi-threaded environment.
