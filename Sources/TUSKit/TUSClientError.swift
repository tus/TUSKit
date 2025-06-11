import Foundation

/// The errors that are passed from TUSClient
public enum TUSClientError: Error {
    
    case couldNotCopyFile(underlyingError: Error)
    case couldNotStoreFile(underlyingError: Error)
    case fileSizeUnknown
    case couldNotLoadData(underlyingError: Error)
    case couldNotStoreFileMetadata(underlyingError: Error)
    case couldNotCreateFileOnServer
    case couldNotUploadFile(underlyingError: Error)
    case couldNotGetFileStatus
    case fileSizeMismatchWithServer
    case couldNotDeleteFile(underlyingError: Error)
    case uploadIsAlreadyFinished
    case couldNotRetryUpload
    case couldNotResumeUpload
    case couldnotRemoveFinishedUploads(underlyingError: Error)
    case receivedUnexpectedOffset
    case missingRemoteDestination
    case rangeLargerThanFile
    case taskCancelled
    case customURLSessionWithBackgroundConfigurationNotSupported
    case emptyUploadRange
    
    public var localizedDescription: String {
        switch self {
        case .couldNotCopyFile(let underlyingError):
            return "Could not copy file: \(underlyingError.localizedDescription)"
        case .couldNotStoreFile(let underlyingError):
            return "Could not store file: \(underlyingError.localizedDescription)"
        case .fileSizeUnknown:
            return "The file size is unknown."
        case .couldNotLoadData(let underlyingError):
            return "Could not load data: \(underlyingError.localizedDescription)"
        case .couldNotStoreFileMetadata(let underlyingError):
            return "Could not store file metadata: \(underlyingError.localizedDescription)"
        case .couldNotCreateFileOnServer:
            return "Could not create file on server."
        case .couldNotUploadFile(let underlyingError):
            return "Could not upload file: \(underlyingError.localizedDescription)"
        case .couldNotGetFileStatus:
            return "Could not get file status."
        case .fileSizeMismatchWithServer:
            return "File size mismatch with server."
        case .couldNotDeleteFile(let underlyingError):
            return "Could not delete file: \(underlyingError.localizedDescription)"
        case .uploadIsAlreadyFinished:
            return "The upload is already finished."
        case .couldNotRetryUpload:
            return "Could not retry upload."
        case .couldNotResumeUpload:
            return "Could not resume upload."
        case .couldnotRemoveFinishedUploads(let underlyingError):
            return "Could not remove finished uploads: \(underlyingError.localizedDescription)"
        case .receivedUnexpectedOffset:
            return "Received unexpected offset."
        case .missingRemoteDestination:
            return "Missing remote destination for upload."
        case .emptyUploadRange:
            return "The upload range is empty."
        case .rangeLargerThanFile:
            return "The upload range is larger than the file size."
        case .taskCancelled:
            return "The task was cancelled."
        case .customURLSessionWithBackgroundConfigurationNotSupported:
            return "Custom URLSession with background configuration is not supported."
        }
    }
}
