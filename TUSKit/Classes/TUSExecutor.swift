//
//  TUSExecutor.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import Foundation

class TUSExecutor: NSObject, URLSessionDelegate {
    
    var customHeaders: [String: String] = [:]
    private var sharedTask: URLSessionDataTask?
    
    // MARK: Private Networking / Upload methods
    
    private func urlRequest(withFullURL url: URL, andMethod method: String, andContentLength contentLength: String?, andUploadLength uploadLength: String?, andFilename fileName: String, andHeaders headers: [String: String]) -> URLRequest {
        
        var request: URLRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.addValue(TUSConstants.TUSProtocolVersion, forHTTPHeaderField: "TUS-Resumable")
        
        if let contentLength = contentLength {
            request.addValue(contentLength, forHTTPHeaderField: "Content-Length")
        }
        
        if let uploadLength = uploadLength {
            request.addValue(uploadLength, forHTTPHeaderField: "Upload-Length")
        }

        for header in headers.merging(customHeaders, uniquingKeysWith: { (current, _) in current }) {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }

        return request
    }
    
    internal func create(forUpload upload: TUSUpload) {
        let request = urlRequest(withFullURL: TUSClient.shared.uploadURL,
                                 andMethod: "POST",
                                 andContentLength: upload.contentLength,
                                 andUploadLength: upload.uploadLength,
                                 andFilename: upload.id,
                                 andHeaders: ["Upload-Extension": "creation", "Upload-Metadata": upload.encodedMetadata])
        
        sharedTask =  TUSClient.shared.tusSession.session.dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    TUSClient.shared.logger.log(forLevel: .Info, withMessage:String(format: "File %@ created", upload.id))
                    // Set the new status and other props for the upload
                    upload.status = .created
//                    upload.contentLength = httpResponse.allHeaderFields["Content-Length"] as? String
                    upload.uploadLocationURL = URL(string: httpResponse.allHeaderFieldsUpper()["LOCATION"]!, relativeTo: TUSClient.shared.uploadURL)
                    //Begin the upload
                    TUSClient.shared.updateUpload(upload)
                    self.upload(forUpload: upload)
                }
            }
        }
        sharedTask!.resume()
    }
    
    internal func upload(forUpload upload: TUSUpload) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        //First we create chunks
        //MARK: FIX THIS
        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Preparing upload data for file %@", upload.id))
        let uploadData = try! Data(contentsOf: URL(fileURLWithPath: String(format: "%@%@%@", TUSClient.shared.fileManager.fileStorePath(), upload.id, upload.fileType!)))
//        let fileName = String(format: "%@%@", upload.id, upload.fileType!)
//        let tusName = String(format: "TUS-%@", fileName)
        //let uploadData = try! UserDefaults.standard.data(forKey: tusName)
        //upload.data = uploadData
//        let chunks: [Data] = createChunks(forData: uploadData)
//        print(chunks.count)
        
        let chunks = dataIntoChunks(data: uploadData,
                                    chunkSize: TUSClient.shared.chunkSize * 1024 * 1024)
        //Then we start the upload from the first chunk
        upload.status = .uploading
        TUSClient.shared.updateUpload(upload)
        self.upload(forChunks: chunks, withUpload: upload, atPosition: 0)
    }
    
    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition position: Int) {
        TUSClient.shared.logger.log(forLevel: .Info, withMessage:String(format: "Upload starting for file %@ - Chunk %u / %u", upload.id, position + 1, chunks.count))
        let request: URLRequest = urlRequest(withFullURL: upload.uploadLocationURL!, andMethod: "PATCH", andContentLength: upload.contentLength!, andUploadLength: nil, andFilename: upload.id, andHeaders: ["Content-Type":"application/offset+octet-stream", "Upload-Offset": upload.uploadOffset!, "Content-Length": String(chunks[position].count), "Upload-Metadata": upload.encodedMetadata])
         let task = TUSClient.shared.tusSession.session.uploadTask(with: request, from: chunks[position], completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<300:
                    //success
                    if (chunks.count > position+1 ){
                        
                        upload.uploadOffset = httpResponse.allHeaderFieldsUpper()["UPLOAD-OFFSET"]
                        TUSClient.shared.updateUpload(upload)
                        if (upload.status == TUSUploadStatus.uploading) {
                            self.upload(forChunks: chunks, withUpload: upload, atPosition: position+1)
                        }
                    } else
                    if (httpResponse.statusCode == 204) {
                        TUSClient.shared.logger.log(forLevel: .Info, withMessage:String(format: "Chunk %u / %u complete", position + 1, chunks.count))
                        if (position + 1 == chunks.count) {
                            TUSClient.shared.logger.log(forLevel: .Info, withMessage:String(format: "File %@ uploaded at %@", upload.id, upload.uploadLocationURL!.absoluteString))
                            TUSClient.shared.updateUpload(upload)
                            TUSClient.shared.delegate?.TUSSuccess(forUpload: upload)
                            TUSClient.shared.cleanUp(forUpload: upload)
                            TUSClient.shared.status = .ready
                            if (TUSClient.shared.currentUploads!.count > 0) {
                                TUSClient.shared.createOrResume(forUpload: TUSClient.shared.currentUploads![0])
                            }
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
        if (TUSClient.shared.currentUploads?.first?.id == upload.id) {
            sharedTask?.cancel()
        }
        upload.status = .canceled
        TUSClient.shared.updateUpload(upload)
        TUSClient.shared.status = .ready
    }
    
    private func dataIntoChunks(data: Data, chunkSize: Int) -> [Data] {
        var chunks = [Data]()
        var chunkStart = 0
        while(chunkStart < data.count) {
            let remaining = data.count - chunkStart
            let nextChunkSize = min(chunkSize, remaining)
            let chunkEnd = chunkStart + nextChunkSize
            
            chunks.append(data.subdata(in: chunkStart..<chunkEnd))
            
            chunkStart = chunkEnd
        }
        return chunks
    }
    
    // MARK: Private Networking / Other methods

    internal func get(forUpload upload: TUSUpload) {
        var request: URLRequest = URLRequest(url: upload.uploadLocationURL!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        //TODO: Fix
        let task = TUSClient.shared.tusSession.session.downloadTask(with: request) { (url, response, error) in
            TUSClient.shared.logger.log(forLevel: .Info, withMessage:response!.description)
        }
    }
}


