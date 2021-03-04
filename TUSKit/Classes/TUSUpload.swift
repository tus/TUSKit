//
//  TUSUpload.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public class TUSUpload: NSObject, NSCoding {
    public func encode(with coder: NSCoder) {
        //
        coder.encode(id, forKey: "id")
        coder.encode(fileType, forKey: "fileType")
        coder.encode(filePath, forKey: "filePath")
        coder.encode(data, forKey: "data")
        coder.encode(uploadLocationURL, forKey: "uploadLocationURL")
        coder.encode(contentLength, forKey: "contentLength")
        coder.encode(uploadLength, forKey: "uploadLength")
        coder.encode(uploadOffset, forKey: "uploadOffset")
        coder.encode(status?.rawValue, forKey: "status")
        coder.encode(prevStatus?.rawValue, forKey: "prevStatus")
        coder.encode(metadata, forKey: "metadata")

    }
    
    public required init?(coder: NSCoder) {
        //
        fileType = coder.decodeObject(forKey:"fileType") as? String
        filePath = coder.decodeObject(forKey:"filePath") as? URL
        uploadLocationURL = coder.decodeObject(forKey:"uploadLocationURL") as? URL
        contentLength = coder.decodeObject(forKey:"contentLength") as? String
        uploadLength = coder.decodeObject(forKey:"uploadLength") as? String
        uploadOffset = coder.decodeObject(forKey:"uploadOffset") as? String
        id = coder.decodeObject(forKey: "id") as! String
        data = coder.decodeObject(forKey: "data") as? Data
        status = TUSUploadStatus(rawValue: coder.decodeObject(forKey: "status") as! String)
        metadata = coder.decodeObject(forKey: "metadata") as! [String : String]
        
        // Migration safe: in previous versions this field did not exists so we set it in a safe manner
        let prevStatusString = coder.decodeObject(forKey: "prevStatus") as? String
        prevStatus = prevStatusString != nil ? TUSUploadStatus(rawValue: prevStatusString!) : nil
    }
    

    // MARK: Properties
    public let id: String
    var fileType: String? // TODO: Make sure only ".fileExtension" gets set. Current setup sets fileType as something like "1A1F31FE6-BB39-4A78-AECD-3C9BDE6D129E.jpeg"
    var filePath: URL?
    var data: Data?
    public var uploadLocationURL: URL?
    var contentLength: String?
    var uploadLength: String?
    var uploadOffset: String?
    var status: TUSUploadStatus?{
        // When the status updates we want to update the previous status
        didSet {
            // Don't update the previous state in the following cases (because we need to know whether a
            // upload state was created/new/uploading (when calling `cancel` mutliple times we would
            // loose this information).
            if (oldValue != TUSUploadStatus.canceled && oldValue != TUSUploadStatus.paused && oldValue != TUSUploadStatus.failed) {
                prevStatus = oldValue
            }
        }
    }
    var prevStatus: TUSUploadStatus?
    public var metadata: [String : String] = [:]
    var encodedMetadata: String {
        metadata["filename"] = getUploadFilename()
        return metadata.map { (key, value) in
            "\(key) \(value.toBase64())"
        }.joined(separator: ",")
    }
    
    public init(withId id: String, andFilePathString filePathString: String, andFileType fileType: String) {
        self.id = id
        filePath = URL(string: filePathString)
        self.fileType = fileType

        super.init()
    }
    
    public init(withId id: String, andFilePathURL filePathURL: URL, andFileType fileType: String) {
        self.id = id
        filePath = filePathURL
        self.fileType = fileType

        super.init()
    }
    
    public init(withId id: String, andData data: Data, andFileType fileType: String) {
        self.id = id
        self.data = data
        self.fileType = fileType
        
        super.init()
    }
    
    public init(withId id: String) {
        self.id = id
        
        super.init()
    }
    
    public func getStatus() -> TUSUploadStatus? {
        return status
    }
    
    public func getUploadFilename() -> String {
        return String(format: "%@%@", self.id, self.fileType!)
    }
}
