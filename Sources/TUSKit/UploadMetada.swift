//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//

import Foundation

/// This type represents data to store on the disk. To allow for persistence between sessions.
/// E.g. For background uploading or when an app is killed, we can use this data to continue where we left off.
/// The reason this is a class is to preserve refernece semantics.
final class UploadMetadata: Codable {
    
    var isFinished: Bool {
        size == uploadedRange?.count
    }
    
    let id: UUID
    let uploadURL: URL
    var filePath: URL
    var remoteDestination: URL?
    let version: Int
    
    let mimeType: String?
    
    let customHeaders: [String: String]?
    var uploadedRange: Range<Int>?
    let size: Int
    var errorCount: Int
    
    init(id: UUID, filePath: URL, uploadURL: URL, size: Int, customHeaders: [String: String]? = nil, mimeType: String? = nil) {
        self.id = id
        self.filePath = filePath
        self.uploadURL = uploadURL
        self.size = size
        self.customHeaders = customHeaders
        self.mimeType = mimeType
        self.version = 1 // Can't make default property because of Codable
        self.errorCount = 0
        // TODO: Check nil size error?
    }
}
