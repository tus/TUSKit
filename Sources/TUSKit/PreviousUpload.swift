//
//  File.swift
//  
//
//  Created by Kidus Solomon on 27/03/2023.
//

import Foundation


public struct PreviousUpload {
    public var id: UUID
    public var uploadURL: URL
    public var filePath: URL
    public var remoteDestination: URL?
    public var context: [String: String]?
    public var uploadedRange: Range<Int>?
    public var mimeType: String?
    public var customHeaders: [String: String]?
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
