//
//  TUSExecutor+get.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 27.02.21.
//

import Foundation

extension TUSExecutor {
    internal func get(forUpload upload: TUSUpload) {
        var request = URLRequest(url: upload.uploadLocationURL!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        // TODO: Fix
        let _ = TUSClient.shared.tusSession.session.downloadTask(with: request) { (url, response, error) in
            TUSClient.shared.logger.log(forLevel: .Info, withMessage:response!.description)
        }
    }
}
