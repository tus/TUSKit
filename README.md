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
var cient: TUSClient = TUSClient("https://master.tus.io/files")

//Set the delegate 
client.delegate = self

//You can also change the file upload URL at anytime
client.uploadURL = "https://newUploadURL.com/files"

//Create a TUS Upload per file you want to upload
//On creation of an upload, the data of an object will be saved to the device until completion of the upload
var newUpload = TUSUpload(withId: "Some Id to refrence a file", andFile: "FilePathHere")
var anotherNewUpload = TUSUpload(withId: "Another Id to refrence a file", andData: DataObject)
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

Before using TUSKit, you must configure your `TUSClient`  using `TUSClient.setup()`. It is recomended to put this in your `AppDelegate`.

**Parameters**
- uploadURL : The upload URL that TUSKit should upload to
- sessionConfiguration: A URLSessionConfiguration that  TUSKit will use for it's network sessions. `URLSessionConfiguration.default` will be used if omitted.

```Swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    TUSClient.setup(with: TUSConfig(withUploadURLString: "https://master.tus.io/files", andSessionConfig: URLSessionConfiguration.default))
    return true
}
```
