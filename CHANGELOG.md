# 3.1.7

# Enhancements
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

# Enhancements
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
