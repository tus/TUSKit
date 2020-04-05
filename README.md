# Proposed changes for TUSKit

#### Goals
- Ditch objective-c and adopt Swift
- Change blocks to delegates
- Replicate the flow of the Android TUS library to bring synergy to TUS mobile native development
- Make it easier for multiple file uploads
- Better support for background sessions

### New usage

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


//Misc functions for resuming
client.currentUploadsUnfinished() //an array of TUSUpload objects of uploads unfinished
client.resumeAll()

//Now upload
client.createOrResumeUpload(TUSUploadObjectHere)
//or
client.createOrResumeUpload(TUSUploadObjectHere, withRetries: 3)


//TUSKitDelegate

func TUSKitProgress(FileID, bytesUploaded, bytesRemaining)
func TUSKitProgress(FileID, bytesUploaded, bytesRemaining)

func TUSKitSuccess(FileID, TUSResponse)

func TUSKitError(FileID, TUSResponse, Error)

```
