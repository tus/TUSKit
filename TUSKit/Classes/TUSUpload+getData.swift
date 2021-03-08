//
//  TUSUpload+getData.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 27.02.21.
//

import Foundation

extension TUSUpload {
    func getData() throws -> Data {
        let data = try Data(contentsOf: URL(fileURLWithPath: String(format: "%@%@", TUSClient.shared.fileManager.fileStorePath(), self.getUploadFilename())))
        return data
    }
}
