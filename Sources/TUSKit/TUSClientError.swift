import Foundation

/// The errors that are passed from TUSClient
public enum TUSClientError: Error {
    
    case couldNotCopyFile(underlyingError: Error)
    case couldNotStoreFile(underlyingError: Error)
    case fileSizeUnknown
    case couldNotLoadData(underlyingError: Error)
    case couldNotStoreFileMetadata(underlyingError: Error)
    case couldNotCreateFileOnServer
    case couldNotUploadFile
    case couldNotGetFileStatus
    case fileSizeMismatchWithServer
    case couldNotDeleteFile(underlyingError: Error)
    case uploadIsAlreadyFinished
    case couldNotRetryUpload
    case couldnotRemoveFinishedUploads(underlyingError: Error)
    case receivedUnexpectedOffset
    case missingRemoteDestination
}
