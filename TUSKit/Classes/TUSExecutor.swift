//
//  TUSExecutor.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import UIKit

class TUSExecutor: NSObject {
    
    let session = TUSClient.shared.session
    
    // MARK: Private Networking / Upload methods
    
    private func urlRequest(withEndpoint endpoint: String, andContentLength contentLength: String, andUploadLength uploadLength: String, andFilename fileName: String) -> URLRequest {
    
        var request: URLRequest = URLRequest(url: (TUSClient.shared.uploadURL?.appendingPathComponent(endpoint))!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.addValue("Content-Length", forHTTPHeaderField: contentLength)
        request.addValue("Upload-Length", forHTTPHeaderField: uploadLength)
        request.addValue("Tus-Resumable", forHTTPHeaderField: TUSConstants.TUSProtocolVersion)
        request.addValue("Upload-Metadata", forHTTPHeaderField: fileName)
        
        return request
    }
    
    internal func create(forUpload upload: TUSUpload) {
        let request: URLRequest = urlRequest(withEndpoint: "", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!)
        self.session!.dataTask(with: request) { (data, response, error) in
            //
        }
    }
    
    internal func upload(forUpload upload: TUSUpload, withChunkSize chunkSize: Int) {
        let request: URLRequest = urlRequest(withEndpoint: "", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!)
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        let chunk: Data = Data()
        self.session!.uploadTask(with: request, from: chunk) { (data, response, error) in
            //
        }
    }
    
    internal func cancel(forUpload upload: TUSUpload) {
        
    }
    
}
