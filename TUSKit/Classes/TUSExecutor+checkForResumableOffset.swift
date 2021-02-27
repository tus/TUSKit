//
//  TUSClient+checkForResumableOffset.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 27.02.21.
//

import Foundation

extension TUSExecutor {
    /// Requesting information at the upload url.
    /// When we receive a 200 response the file has been previously uploaded
    /// and we need to resume the upload at the responded `ContentOffset`
    /// See https://tus.io/protocols/resumable-upload.html#core-protocol
    func checkForResumableOffset(uploadUrl: URL, callback: @escaping ((Int?) -> Void)) {
        var headRequest: URLRequest = URLRequest(url: uploadUrl)
        headRequest.httpMethod = "HEAD"
        headRequest.addValue(TUSConstants.TUSProtocolVersion, forHTTPHeaderField: "TUS-Resumable")
        let headTask = TUSClient.shared.tusSession.session.dataTask(with: headRequest) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                let contentOffset = httpResponse.allHeaderFieldsUpper()["UPLOAD-OFFSET"]
                
                if httpResponse.statusCode == 200 && contentOffset != nil {
                    callback(Int(contentOffset!))
                } else {
                    callback(nil)
                }
            } else {
                callback(nil)
            }
        }
        headTask.resume();
    }
}
