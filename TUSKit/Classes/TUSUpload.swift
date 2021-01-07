//
//  TUSUpload.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public class TUSUpload: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case metadata
        case uploadLocationURL
        case filePath
        case data
        case fileName
        case contentLength
        case uploadLength
        case uploadOffset
        case status
    }
    
    // MARK: Properties
    public let id: String
    public var uploadLocationURL: URL?
    let filePath: URL?
    let data: Data?
    let fileName: String
    var contentLength: String?
    var uploadLength: String?
    var uploadOffset: String?
    var status: TUSUploadStatus = .new
    private let metadata: [String : String]
    
    var encodedMetadata: String {
        return metadata.map { (key, value) in
            "\(key) \(value.toBase64())"
        }.joined(separator: ",")
    }
    
    /// Initializes an upload object with the provided string.
    /// - Parameters:
    ///   - id: A unique identifier for the upload.
    ///   - filePathString: String represention of the URL for the file.
    ///   - fileExtension: The  extension of the file to be uploaded, example: ".jpg"
    ///   - metadata: Additional metadata for the upload.
    public convenience init?(withId id: String, andFilePathString filePathString: String, andFileExtension fileExtension: String, metadata: [String: String] = [String: String]()) {
        guard let url = URL(string: filePathString) else { return nil }
        
        self.init(withId: id, andFilePathURL: url, andFileExtension: fileExtension, metadata: metadata)
    }
    
    /// Initializes an upload object with the provided URL.
    /// - Parameters:
    ///   - id: A unique identifier for the upload.
    ///   - filePathURL: The URL for the file.
    ///   - fileExtension: The  extension of the file to be uploaded, example: ".jpg"
    ///   - metadata: Additional metadata for the upload.
    public init(withId id: String, andFilePathURL filePathURL: URL, andFileExtension fileExtension: String, metadata: [String: String] = [String: String]()) {
        self.id = id
        filePath = filePathURL
        fileName = id + fileExtension
        data = nil
        
        var mutableMetadata = metadata
        mutableMetadata["filename"] = fileName
        
        self.metadata = mutableMetadata
    }
    
    /// Initializes an upload object with the provided data.
    /// - Parameters:
    ///   - id: A unique identifier for the upload.
    ///   - data: The file to be uploaded's data.
    ///   - fileExtension: The  extension of the file to be uploaded, example: ".jpg".
    ///   - metadata: Additional metadata for the upload.
    public init(withId id: String, andData data: Data, andFileExtension fileExtension: String, metadata: [String: String] = [String: String]()) {
        self.id = id
        self.data = data
        fileName = id + fileExtension
        filePath = nil
        
        var mutableMetadata = metadata
        mutableMetadata["filename"] = fileName
        
        self.metadata = mutableMetadata
    }
}
