//
//  TUSUpload.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

class TUSUpload: NSObject {
    
    // MARK: Properties
    var id: String?
    var fileType: String?
    var filePath: URL?
    var data: Data?
    var status: TUSUploadStatus? {
       get {
        guard let status = UserDefaults.standard.value(forKey: String(format: "%@%@", TUSConstants.kSavedTUSStatusDefaultsKey, id!)) as? String else {
               return nil
           }
           return TUSUploadStatus(rawValue: status)
       }
       set(status) {
        UserDefaults.standard.set(status?.rawValue, forKey: String(format: "%@%@", TUSConstants.kSavedTUSStatusDefaultsKey, id!))
       }
    }
    
    init(withId id: String, andFilePathString filePathString: String) {
        self.id = id
        filePath = URL(string: filePathString)
    }
    
    init(withId id: String, andFilePathURL filePathURL: URL) {
        self.id = id
        filePath = filePathURL
    }
    
    init(withId id: String, andData data: Data) {
        self.id = id
        self.data = data
    }
    
    init(withId id: String) {
        self.id = id
    }
}
