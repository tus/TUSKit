//
//  File.swift
//  
//
//  Created by Kidus Solomon on 27/03/2023.
//

import Foundation


public struct UploadInfo {
    public let id: UUID
    public let uploadURL: URL
    public let filePath: URL
    public let remoteDestination: URL?
    public let context: [String: String]?
    public let uploadedRange: Range<Int>?
    public let mimeType: String?
    public let customHeaders: [String: String]?
    public let size: Int
    
    init(id: UUID, uploadURL: URL, filePath: URL, remoteDestination: URL? = nil, context: [String : String]? = nil, uploadedRange: Range<Int>? = nil, mimeType: String? = nil, customHeaders: [String : String]? = nil, size: Int) {
        self.id = id
        self.uploadURL = uploadURL
        self.filePath = filePath
        self.remoteDestination = remoteDestination
        self.context = context
        self.uploadedRange = uploadedRange
        self.mimeType = mimeType
        self.customHeaders = customHeaders
        self.size = size
    }
    
}
