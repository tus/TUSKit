# Swift Rewrite of TUSKit 
[![Protocol](http://img.shields.io/badge/tus_protocol-v1.0.0-blue.svg?style=flat)](http://tus.io/protocols/resumable-upload.html)
[![Version](https://img.shields.io/cocoapods/v/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![License](https://img.shields.io/cocoapods/l/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)
[![Platform](https://img.shields.io/cocoapods/p/TUSKit.svg?style=flat)](http://cocoadocs.org/docsets/TUSKit)

An iOS client written in `Swift` for [tus resumable upload protocol](http://tus.io/).

# Proposed changes for TUSKit

#### Goals
- Ditch objective-c and adopt Swift
- Change blocks to delegates
- Replicate the flow of the Android TUS library to bring synergy to TUS mobile native development
- Make it easier for multiple file uploads
- Better support for background sessions

### Proposed new usage

```Swift


// Init and setup the file upload url
var client: TUSClient = TUSClient("https://master.tus.io/files")

//Set the delegate 
client.delegate = self

//You can also change the file upload URL at anytime
client.uploadURL = "https://newUploadURL.com/files"

//Create a TUS Upload per file you want to upload
//On creation of an upload, the data of an object will be saved to the device until completion of the upload
var newUpload = TUSUpload(withId: "Some Id to reference a file", andFile: "FilePathHere")
var anotherNewUpload = TUSUpload(withId: "Another Id to reference a file", andData: DataObject)
var previousUpload = TUSUpload(withId: "Just an ID of a past upload")

//Misc functions for client
client.cancel(TUSUpload) ///Cancel the upload of a specific upload
client.retry(TUSUpload) ///Retry the upload of a specific upload
client.cancelAll() //Cancels all uploads
client.retryAll() //retires all uploads 
client.currentUploads() //an array of TUSUpload objects of uploads unfinished
client.uploadStatus //An enum TUSStatus - either set to `uploading` `paused` `finished`
client.retryAll()
client.resumeAll()
client.cancelAll()
client.cleanUp() //Deletes local files of canceled or failed uploads - Files cannot be resumed after this is fired

//Now upload
client.createOrResumeUpload(TUSUploadObjectHere)
//or
client.createOrResumeUpload(TUSUploadObjectHere, withRetries: 3)


//TUSKitDelegate

func TUSProgress(bytesUploaded, bytesRemaining) //overall current upload progress

func TUSProgress(TUSUpload, bytesUploaded, bytesRemaining) //Per file upload progress

func TUSSuccess(TUSUpload, TUSResponse)

func TUSFailure(TUSUpload, TUSResponse, Error)

```

# Usage

## Installation

Before using TUSKit, you must configure your `TUSClient`  using `TUSClient.setup()`. It is recommended to put this in your `AppDelegate`.

**Parameters**
- uploadURL : The upload URL that TUSKit should upload to
- sessionConfiguration: A URLSessionConfiguration that  TUSKit will use for it's network sessions. `URLSessionConfiguration.default` will be used if omitted.

```Swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    var config = TUSConfig(withUploadURLString: "https://master.tus.io/files", andSessionConfig: URLSessionConfiguration.default)
    TUSClient.setup(with: config)
    return true
}
```

### Logging

An optional property can be set to allow TUSKit to log to the console, in order to help you debug or just for better insight to the actions taking place

```Swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    var config = TUSConfig(withUploadURLString: "https://master.tus.io/files", andSessionConfig: URLSessionConfiguration.default)
    config.debugLogEnabled = true // Set logging on
    TUSClient.setup(with: config)
    return true
}
```

**Example output logs**
```
TUSKit: Creating file image49 on server
TUSKit: File image49 created
TUSKit: Preparing upload data for file image49
TUSKit: Upload starting for file image49
```

## TUSUpload
An object that holds your uploads data and state. It can be created from a file, data or referenced with just an Id.

```Swift 
//A new upload for a file
var uploadObject = TUSUpload(withId: "Some Id to reference a file", andFile: "FilePathHere")

//A new upload for data
var uploadObject = TUSUpload(withId: "Another Id to reference a file", andData: DataObject)

//An existing upload
var uploadObject = TUSUpload(withId: "Just an ID of a past upload") //Will fail out if data on the device matching the ID isn't found.

```

## TUSClient
`TUSClient` is a singleton used to communicate from your application to your `TUS` server. It will handle all file creation, uploads, and other operations alike.

### Create
You can create an upload and start the upload process by passing an upload object.

**Parameters**
withRetries: The number of silent retries to take place before failing out to the delegate

```Swift
TUSClient.shared.createOrResume(uploadObject) //Create and start upload
```

### Pause
You can pause a specific upload, or all uploads. If an upload is paused, it will not be deleted when running the `cleanUp()` method.

```Swift
TUSClient.shared.pause(uploadObject) //Pause a specific upload
TUSClient.shared.pauseAll() //Pause all uploads
```

### Resume
You can resume a specific upload, or all uploads that have previously been paused- not canceled or failed. If an upload is resumed it will resume the upload from where it last left off.

```Swift
TUSClient.shared.createOrResume(uploadObject) //Cancel a specific upload
TUSClient.shared.resumeAll() //Cancel all uploads
```

### Retry
You can retry a specific upload, or all uploads that have previously been canceled or failed - not paused. If an upload is retired it will attempt to create the file on your `TUS` server, if already existing it will begin or resume the upload from where it last left off.

```Swift
TUSClient.shared.retry(uploadObject) //Cancel a specific upload
TUSClient.shared.retryAll() //Cancel all uploads
```

### Cancel
You can cancel and suspend a specific upload, or all uploads. Canceling an upload will terminate the upload process until retried or cleaned up.

```Swift
TUSClient.shared.cancel(uploadObject) //Cancel a specific upload
TUSClient.shared.cancelAll() //Cancel all uploads
```

### Clean Up
You can clean up and clear all failed, and canceled uploads or a specific upload from your applications disk-space and memory. After cleanup your file data will no longer be on the device, but the file and any previously uploaded data may still be present on your `TUS` server. 

```Swift
TUSClient.shared.cleanUp(uploadObject) //cleanup all
TUSClient.shared.cleanUpAll() //cleanup all
```

## Delegate

### Progress 
You can track the progress of specific uploads, or all uploads
```Swift
func TUSProgress(bytesUploaded, bytesRemaining) //overall current upload progress
func TUSProgress(TUSUpload, bytesUploaded, bytesRemaining) //Per file upload progress
```

### Success
The delegate method when a file successfully uploads
```Swift
func TUSSuccess(TUSUpload, TUSResponse)
```

### Failure
The delegate method fire when a file stops (canceled, failure, or paused)


```Swift
func TUSFailure(TUSUpload, TUSResponse)
```
