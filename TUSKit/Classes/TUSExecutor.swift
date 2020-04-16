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
    
    internal func upload(forUpload upload: TUSUpload, withChunkSizeInMB mbSize: Int) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        //First we create chunks
        let chunks: [Data] = createChunks(forData: upload.data!, inMBSize: mbSize)
        
        //Then we start the upload from the first chunk
        self.upload(forChunks: chunks, withUpload: upload, atPosition: 0)
    }
    
    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition position: Int ) {
        let request: URLRequest = urlRequest(withEndpoint: "", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!)
        self.session?.uploadTask(with: request, from: chunks[position], completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<300:
                    //success
                    if (chunks.count < position){
                        self.upload(forChunks: chunks, withUpload: upload, atPosition: position+1)
                    }
                    break
                case 400..<500:
                    //reuqest error
                    break
                case 500..<600:
                    //server
                    break
                default: break
                }
            }
        })
    }
    
    internal func cancel(forUpload upload: TUSUpload) {
        
    }
    
    private func createChunks(forData data: Data, inMBSize mbSize: Int) -> [Data] {
        //Thanks Sean Behan!
        let data = Data()
        let dataLen = data.count
        let chunkSize = ((1024 * 1000) * mbSize)
        let fullChunks = Int(dataLen / chunkSize)
        let totalChunks = fullChunks + (dataLen % 1024 != 0 ? 1 : 0)
        var chunks:[Data] = [Data]()
        for chunkCounter in 0..<totalChunks {
            var chunk:Data
            let chunkBase = chunkCounter * chunkSize
            var diff = chunkSize
            if(chunkCounter == totalChunks - 1) {
                diff = dataLen - chunkBase
            }
            let range:Range<Data.Index> = Range<Data.Index>(chunkBase..<(chunkBase + diff))
            chunk = data.subdata(in: range)
            chunks.append(chunk)
        }
        return chunks
    }
    
}
