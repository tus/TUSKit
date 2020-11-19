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

    }
    
    public required init?(coder: NSCoder) {
        //
        id = coder.decodeObject(forKey:"id") as? String
        fileType = coder.decodeObject(forKey:"fileType") as? String
        filePath = coder.decodeObject(forKey:"filePath") as? URL
        uploadLocationURL = coder.decodeObject(forKey:"uploadLocationURL") as? URL
        contentLength = coder.decodeObject(forKey:"contentLength") as? String
        uploadLength = coder.decodeObject(forKey:"uploadLength") as? String
        uploadOffset = coder.decodeObject(forKey:"uploadOffset") as? String
        data = coder.decodeObject(forKey: "data") as? Data
        status = TUSUploadStatus(rawValue: coder.decodeObject(forKey: "status") as! String)
    }
    
    
    // MARK: Properties
    var id: String?
    var fileType: String? // TODO: Make sure only ".fileExtension" gets set. Current setup sets fileType as something like "1A1F31FE6-BB39-4A78-AECD-3C9BDE6D129E.jpeg"
    var filePath: URL?
    var data: Data?
    public var uploadLocationURL: URL?
    var contentLength: String?
    var uploadLength: String?
    var uploadOffset: String?
    var status: TUSUploadStatus?
    
    public init(withId id: String, andFilePathString filePathString: String, andFileType fileType: String) {
        super.init()
        self.id = id
        filePath = URL(string: filePathString)
        self.fileType = fileType

    }
    
    public init(withId id: String, andFilePathURL filePathURL: URL, andFileType fileType: String) {
        super.init()
        self.id = id
        filePath = filePathURL
        self.fileType = fileType
    }
    
    public init(withId id: String, andData data: Data, andFileType fileType: String) {
        self.id = id
        self.data = data
        self.fileType = fileType
    }
    
    public init(withId id: String) {
        self.id = id
    }
}
