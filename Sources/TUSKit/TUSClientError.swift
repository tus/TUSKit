//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 07/10/2021.
//

import Foundation

/// The errors that are passed from TUSClient
public struct TUSClientError: Error {
    // Maintenance: We use static lets on a struct, instead of an enum, so that adding new cases won't break stability.
    // Alternatively we can ask users to always use `unknown default`, but we can't guarantee that everyone will use that.
    
    let code: Int
    
    public static let couldNotCopyFile = TUSClientError(code: 1)
    public static let couldNotStoreFile = TUSClientError(code: 2)
    public static let fileSizeUnknown = TUSClientError(code: 3)
    public static let couldNotLoadData = TUSClientError(code: 4)
    public static let couldNotStoreFileMetadata = TUSClientError(code: 5)
    public static let couldNotCreateFileOnServer = TUSClientError(code: 6)
    public static let couldNotUploadFile = TUSClientError(code: 7)
    public static let couldNotGetFileStatus = TUSClientError(code: 8)
    public static let fileSizeMismatchWithServer = TUSClientError(code: 9)
    public static let couldNotDeleteFile = TUSClientError(code: 10)
    public static let uploadIsAlreadyFinished = TUSClientError(code: 11)
    public static let couldNotRetryUpload = TUSClientError(code: 12)
    public static let couldnotRemoveFinishedUploads = TUSClientError(code: 13)
    public static let receivedUnexpectedOffset = TUSClientError(code: 14)
}
