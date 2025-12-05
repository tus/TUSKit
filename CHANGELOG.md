# 3.7.0

- Removed cocoapods support

## Bugfix
- Canceling a task by id no longer continues retrying the task automatically ([#214](https://github.com/tus/TUSKit/issues/214))

## Feature
- Return response from server when creation of resource failed ([#212](https://github.com/tus/TUSKit/issues/212))
- Clients can now pass in a custom header generator ([#216](https://github.com/tus/TUSKit/issues/216)), ([#211](https://github.com/tus/TUSKit/issues/211))
- TUSClientDelegate.fileError now includes upload identifier ([#215](https://github.com/tus/TUSKit/issues/215))

# 3.6.0

## Bugfix
- Uploads no longer consume large amounts of memory when resuming an upload ([#204](https://github.com/tus/TUSKit/issues/204))
- Uploads no longer start over when they're paused and resumed ([#204](https://github.com/tus/TUSKit/issues/204))
- Better handling of background URLSessions provided by developers ([#206](https://github.com/tus/TUSKit/issues/206) by [dsandriyanov](https://github.com/dsandriyanov))

# 3.5.0

## Bugfix
- Fixed potential race conditions when concurrently starting and stopping uploads. ([#201](https://github.com/tus/TUSKit/pull/201) by [@fantast1k](https://github.com/fantast1k))
- Uploads that got cancelled by force closing an app didn't get retried on app launch (Issue: [#200](https://github.com/tus/TUSKit/issues/200))

# 3.4.3

## Bugfix
- Fixed an issue where the total progress was not being updated correctly when using chunked uploads.
- Fixed an issue where total progress would not include in progress uploads.

# 3.4.2

## Bugfix
- Removed a force-unwrap that would crash if the SDK can't write files.

# 3.4.1

## Bugfix
- Corrected a mistake in delete file logic

# 3.4.0

## Bugfix
- Fixed an issue that prevented TUSKit from uploading large files (2GB+) [#193](https://github.com/tus/TUSKit/issues/193)**

# 3.3.0

## Enhancements

- Updated documentation around background uploads

## Bugfix
- Fixed an issue with macOS not having a correct path when resuming uploads. Thanks, [@MartinLau7](https://github.com/MartinLau7)
- Fixed a metadta issue on iOS. Thanks, [@MartinLau7](https://github.com/MartinLau7)
- Fixed some issues with metadata not alwasy being cleaned up properly for all platforms. Thanks, [@MartinLau7](https://github.com/MartinLau7)
  
# 3.2.1

## Enhancements

- Improved UI for the TUSKit example app. Thanks, [@srvarma7](https://github.com/srvarma7)
- TUSKit no longer sends unneeded Upload-Extension header on creation. Thanks, [@BradPatras](https://github.com/BradPatras)

## Bugfix
- Fixed `didStartUpload` delegate method not being called. Thanks, [@dmtrpetrov](https://github.com/dmtrpetrov)
- Retrying uploads didn't work properly, retry and resume are now seperate methods. Thanks, [@liyoung47](https://github.com/liyoung47) for reporting.

# 3.2

## Enhancements

- TUSKit can now leverage Background URLSession to allow uploads to continue while an app is backgrounded. See the README.md for instructions on migrating to leverage this functionality.

# 3.1.7

## Enhancements
- It's now possible to inspect the status code for failed uploads that did not have a 200 OK HTTP status code. See the following example from the sample app:

```swift
func uploadFailed(id: UUID, error: Error, context: [String : String]?, client: TUSClient) {
    Task { @MainActor in
        uploads[id] = .failed(error: error)
        
        if case TUSClientError.couldNotUploadFile(underlyingError: let underlyingError) = error,
           case TUSAPIError.failedRequest(let response) = underlyingError {
            print("upload failed with response \(response)")
        }
    }
}
```

# 3.1.6

## Enhancements
- Added ability to fetch in progress / current uploads using `getStoredUploads()` on a `TUSClient` instance.

# 3.1.5
## Fixed
- Fixed issue with missing custom headers.

# 3.1.4
## Fixed
- Fix compile error Xcode 14

# 3.1.3
## Fixed
- Added `supportedExtensions` to client

# 3.1.2
## Fixed
- Adding custom headers to requests.

# 3.1.1
## Fixed
- Compile error in `TUSBackground`

# 3.1.0
## Added
- ChunkSize argument to TUSClient initializer.
- Add cancel single task.

# 3.0.0
- Rewrite of TUSKit
