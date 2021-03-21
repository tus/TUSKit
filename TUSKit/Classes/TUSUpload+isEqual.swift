//
//  TUSUpload+isEqual.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 03.03.21.
//

import Foundation

extension TUSUpload {
    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TUSUpload {
            return self.id == object.id
                && self.filePath == object.filePath
                && self.fileType == object.fileType
                && self.metadata == object.metadata
                && self.status == object.getStatus()
                && self.data == object.data
            
        }
        return false;
    }
}
