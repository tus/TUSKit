//
//  TUSExecutor.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import UIKit

class TUSExecutor: NSObject {
    
    // MARK: Private Networking / Upload methods
    
    private func urlRequest(withEndpoint endpoint: String, andMethod method: String, andContentLength contentLength: String, andUploadLength uploadLength: String, andFilename fileName: String, andHeaders headers: [String: String]) -> URLRequest {

        return urlRequest(withFullURL: ((TUSClient.shared.uploadURL?.appendingPathComponent(endpoint))!), andMethod: method, andContentLength: contentLength, andUploadLength: uploadLength, andFilename: fileName, andHeaders: headers)
    }
    
    private func urlRequest(withFullURL url: URL, andMethod method: String, andContentLength contentLength: String, andUploadLength uploadLength: String, andFilename fileName: String, andHeaders headers: [String: String]) -> URLRequest {
        
        var request: URLRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method
//        request.addValue(contentLength, forHTTPHeaderField: "Content-Length")
//        request.addValue(uploadLength, forHTTPHeaderField: "Upload-Length")
        request.addValue(TUSConstants.TUSProtocolVersion, forHTTPHeaderField: "TUS-Resumable")
        request.addValue(String(format: "%@ %@", "filename", fileName.toBase64()), forHTTPHeaderField: "Upload-Metadata")
        
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }

        return request
    }
    
    internal func create(forUpload upload: TUSUpload) {
        var request: URLRequest = urlRequest(withEndpoint: "", andMethod: "POST", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!, andHeaders: ["Upload-Extension": "creation"])
        request.addValue(upload.contentLength!, forHTTPHeaderField: "Content-Length")
        request.addValue(upload.uploadLength!, forHTTPHeaderField: "Upload-Length")
        let task =  TUSClient.shared.tusSession.session.dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    TUSClient.shared.logger.log(String(format: "File %@ created", upload.id!))
                    // Set the new status and other props for the upload
                    upload.status = .created
//                    upload.contentLength = httpResponse.allHeaderFields["Content-Length"] as? String
                    upload.uploadLocationURL = URL(string: httpResponse.allHeaderFields["Location"] as! String)
                    //Begin the upload
                    self.upload(forUpload: upload)
                }
            }
        }
        task.resume()
    }
    
    internal func upload(forUpload upload: TUSUpload) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        //First we create chunks
        //MARK: FIX THIS
        TUSClient.shared.logger.log(String(format: "Preparing upload data for file %@", upload.id!))
        let uploadData = try! Data(contentsOf: URL(fileURLWithPath: String(format: "%@%@%@", TUSClient.shared.fileManager.fileStorePath(), upload.id!, upload.fileType!)))
        
//        let chunks: [Data] = createChunks(forData: uploadData)
//        print(chunks.count)
        let chunks: [Data] = [uploadData]
        //Then we start the upload from the first chunk
        self.upload(forChunks: chunks, withUpload: upload, atPosition: 0)
    }
    
    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition position: Int ) {
        TUSClient.shared.logger.log(String(format: "Upload starting for file %@ - Chunk %u / %u", upload.id!, position + 1, chunks.count))
        let request: URLRequest = urlRequest(withFullURL: upload.uploadLocationURL!, andMethod: "PATCH", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!, andHeaders: ["Content-Type":"application/offset+octet-stream", "Upload-Offset": "0"])
         let task = TUSClient.shared.tusSession.session.uploadTask(with: request, from: chunks[0], completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<300:
                    //success
                    if (chunks.count < position ){
                        self.upload(forChunks: chunks, withUpload: upload, atPosition: position+1)
                    } else
                    if (httpResponse.statusCode == 204) {
                        TUSClient.shared.logger.log(String(format: "Chunk %u / %u complete", position + 1, chunks.count))
                        if (position + 1 == chunks.count) {
                            TUSClient.shared.logger.log(String(format: "File %@ uploaded at %@", upload.id!, upload.uploadLocationURL!.absoluteString))
                        }
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
        task.resume()
    }
    
    internal func cancel(forUpload upload: TUSUpload) {
        
    }
    
    private func createChunks(forData data: Data) -> [Data] {
        print("data")
        print(data.count)
        let mbSize = TUSClient.shared.chunkSize
        //Thanks Sean Behan!
        let data = Data()
        let dataLen = data.count
        let chunkSize = ((1024 * 1000) * mbSize)
        let fullChunks = Int(dataLen / chunkSize)
        let totalChunks = fullChunks + (dataLen % 1024 != 0 ? 1 : 0)
        print(totalChunks)
        var chunks:[Data] = [Data]()
        for chunkCounter in 0..<totalChunks {
            var chunk:Data
            let chunkBase = chunkCounter * chunkSize
            var diff = chunkSize
            if(chunkCounter == totalChunks - 1) {
                diff = dataLen - chunkBase
            }
            let range:Range<Data.Index> = chunkBase..<(chunkBase + diff)
            chunk = data.subdata(in: range)
            print(chunk.debugDescription)
            chunks.append(chunk)
        }
        return chunks
    }
    
}


extension Int {
    var byteSize: String {
        return ByteCountFormatter().string(fromByteCount: Int64(self))
    }
}
