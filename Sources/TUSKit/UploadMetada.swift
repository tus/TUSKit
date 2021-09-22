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
    
    let id: UUID
    var filePath: URL
    var remoteDestination: URL?
    let version: Int
    
    let mimeType: String?
    
    var uploadedRange: Range<Int>?
    let size: Int
    var errorCount: Int
    
    init(id: UUID, filePath: URL, size: Int, mimeType: String? = nil) {
        self.id = id
        self.filePath = filePath
        self.size = size
        self.mimeType = mimeType
        self.version = 1 // Can't make default property because of Codable
        self.errorCount = 0
        // TODO: Check nil size error?
    }
}
