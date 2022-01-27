//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//

import Foundation

/// This type represents data to store on the disk. To allow for persistence between sessions.
/// E.g. For background uploading or when an app is killed, we can use this data to continue where we left off.
/// The reason this is a class is to preserve reference semantics while the data is being updated.
final class UploadMetadata: Codable {
    
    let queue = DispatchQueue(label: "com.tuskit.uploadmetadata")
    
    enum CodingKeys: String, CodingKey {
        case id
        case uploadURL
        case filePath
        case remoteDestination
        case version
        case context
        case uploadedRange
        case mimeType
        case customHeaders
        case size
        case errorCount
        
    }
    
    var isFinished: Bool {
        size == uploadedRange?.count
    }
    
    private var _id: UUID
    var id: UUID {
        get {
            queue.sync {
                _id
            }
        } set {
            queue.async {
                self._id = newValue
            }
        }
    }
    
    let uploadURL: URL
    
    private var _filePath: URL
    var filePath: URL {
        get {
            queue.sync {
                _filePath
            }
        } set {
            queue.async {
                self._filePath = newValue
            }
        }
    }
    
    private var _remoteDestination: URL?
    var remoteDestination: URL? {
        get {
            queue.sync {
                _remoteDestination
            }
        } set {
            queue.async {
                self._remoteDestination = newValue
            }
        }
    }
    
    private var _uploadedRange: Range<Int>?
    /// The total range that's uploaded
    var uploadedRange: Range<Int>? {
        get {
            queue.sync {
                self._uploadedRange
            }
        } set {
            queue.async {
                self._uploadedRange = newValue
            }
        }
    }
    
    
    let version: Int
    
    let context: [String: String]?
    
    let mimeType: String?
    
    let customHeaders: [String: String]?
    let size: Int
    
    private var _errorCount: Int
    /// Number of times the upload failed
    var errorCount: Int {
        get {
            queue.sync {
                _errorCount
            }
        } set {
            queue.sync {
                _errorCount = newValue
            }
        }
    }
    
    init(id: UUID, filePath: URL, uploadURL: URL, size: Int, customHeaders: [String: String]? = nil, mimeType: String? = nil, context: [String: String]? = nil) {
        self._id = id
        self._filePath = filePath
        self.uploadURL = uploadURL
        self.size = size
        self.customHeaders = customHeaders
        self.mimeType = mimeType
        self.version = 1 // Can't make default property because of Codable
        self.context = context
        self._errorCount = 0
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        _id = try values.decode(UUID.self, forKey: .id)
        uploadURL = try values.decode(URL.self, forKey: .uploadURL)
        _filePath = try values.decode(URL.self, forKey: .filePath)
        _remoteDestination = try values.decode(URL?.self, forKey: .remoteDestination)
        version = try values.decode(Int.self, forKey: .version)
        context = try values.decode([String: String]?.self, forKey: .context)
        _uploadedRange = try values.decode(Range<Int>?.self, forKey: .uploadedRange)
        mimeType = try values.decode(String?.self, forKey: .mimeType)
        customHeaders = try values.decode([String: String]?.self, forKey: .customHeaders)
        size = try values.decode(Int.self, forKey: .size)
        _errorCount = try values.decode(Int.self, forKey: .errorCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_id, forKey: .id)
        try container.encode(uploadURL, forKey: .uploadURL)
        try container.encode(_remoteDestination, forKey: .remoteDestination)
        try container.encode(_filePath, forKey: .filePath)
        try container.encode(version, forKey: .version)
        try container.encode(context, forKey: .context)
        try container.encode(uploadedRange, forKey: .uploadedRange)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(customHeaders, forKey: .customHeaders)
        try container.encode(size, forKey: .size)
        try container.encode(_errorCount, forKey: .errorCount)
    }
    
}
