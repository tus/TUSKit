//
//  TUSConstants.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

struct TUSConstants {
    static let TUSProtocolVersion = "1.0.0"
    static let TUSFileDirectoryName = "/TUS/"
    static let kSavedTUSUploadsDefaultsKey = "tusCurrentUploads"
    static let kSavedTUSClientStatusDefaultsKey = "tusClientSavedStatus"
    static let kSavedTUSUploadStatusDefaultsKey = "tusUploadSavedStatusForId-"
    static let kSavedTUSUploadLengthDefaultsKey = "tusUploadSavedUploadLengthForId-"
    static let kSavedTUSUContentLengthDefaultsKey = "tusUploadSavedContentLengthForId-"

    static let chunkSize = 5 // in MB

    static func defaultsStatusKey(forId id: String) -> String {
        return String(format: "%@%@", TUSConstants.kSavedTUSUploadStatusDefaultsKey, id)
    }
    
    static func defaultsContentLengthKey(forId id: String) -> String {
        return String(format: "%@%@", TUSConstants.kSavedTUSUContentLengthDefaultsKey, id)
    }
    
    static func defaultsUploadLengthKey(forId id: String) -> String {
           return String(format: "%@%@", TUSConstants.kSavedTUSUploadLengthDefaultsKey, id)
       }
}
