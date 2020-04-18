//
//  TUSUpload.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

public class TUSUpload: NSObject {
    
    // MARK: Properties
    var id: String?
    var fileType: String? // TODO: Make sure only ".fileExtension" gets set. Current setup sets fileType as something like "1A1F31FE6-BB39-4A78-AECD-3C9BDE6D129E.jpeg"
    var filePath: URL?
    var data: Data?
    internal var uploadLocationURL: URL?

    
    var contentLength: String? {
           get {
               guard let contentLength = UserDefaults.standard.value(forKey: TUSConstants.defaultsContentLengthKey(forId: id!)) as? String else {
                   return nil
               }
               return contentLength
           }
           set(contentLength) {
               UserDefaults.standard.set(contentLength, forKey: String(format: "%@", TUSConstants.defaultsContentLengthKey(forId: id!)))
           }
       }
    
    var uploadLength: String? {
        get {
            guard let uploadLength = UserDefaults.standard.value(forKey: TUSConstants.defaultsUploadLengthKey(forId: id!)) as? String else {
                return nil
            }
            return uploadLength
        }
        set(uploadLength) {
            UserDefaults.standard.set(uploadLength, forKey: String(format: "%@", TUSConstants.defaultsUploadLengthKey(forId: id!)))
        }
    }
    
    var status: TUSUploadStatus? {
        get {
            guard let status = UserDefaults.standard.value(forKey: TUSConstants.defaultsStatusKey(forId: id!)) as? String else {
                return .new
            }
            return TUSUploadStatus(rawValue: status)
        }
        set(status) {
            UserDefaults.standard.set(status?.rawValue, forKey: String(format: "%@", TUSConstants.defaultsStatusKey(forId: id!)))
        }
    }
    
    public init(withId id: String, andFilePathString filePathString: String) {
        super.init()
        self.id = id
        filePath = URL(string: filePathString)
        fileType = filePath?.lastPathComponent
    }
    
    public init(withId id: String, andFilePathURL filePathURL: URL) {
        super.init()
        self.id = id
        filePath = filePathURL
        fileType = filePath?.lastPathComponent
    }
    
    public init(withId id: String, andData data: Data) {
        self.id = id
        self.data = data
    }
    
    public init(withId id: String) {
        self.id = id
    }
}
