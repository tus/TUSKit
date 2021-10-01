//
//  StatusTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// A `StatusTask` fetches the status of an upload. It fetches the offset from we can continue uploading, and then makes a possible uploadtask.
final class StatusTask: Task {
    
    let api: TUSAPI
    let files: Files
    let remoteDestination: URL
    let metaData: UploadMetadata
    let chunkSize: Int
    weak var sessionTask: URLSessionDataTask?
    
    init(api: TUSAPI, remoteDestination: URL, metaData: UploadMetadata, files: Files, chunkSize: Int) {
        self.api = api
        self.remoteDestination = remoteDestination
        self.metaData = metaData
        self.files = files
        self.chunkSize = chunkSize
    }
    
    func run(completed: @escaping TaskCompletion) {
        // Improvement: On failure, try uploading from the start. Create creationtask.
        sessionTask = api.status(remoteDestination: remoteDestination) { [unowned self] result in
            do {
                let status = try result.get()
                let length = status.length
                let offset = status.offset
                if length != metaData.size {
                    throw TUSClientError.fileSizeMismatchWithServer
                }
                
                if offset > metaData.size {
                    throw TUSClientError.fileSizeMismatchWithServer
                }
                
                metaData.uploadedRange = 0..<offset
                
                try files.encodeAndStore(metaData: metaData)
                
                if offset == metaData.size {
                    completed(.success([]))
                } else {
                    let range = offset..<metaData.size
                    let chunkSize = range.count
                    let nextRange = offset..<min((offset + chunkSize), metaData.size)
                    
                    let task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange)
                    completed(.success([task]))
                }
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotGetFileStatus))
            }
            
        }
    }
    
    func cancel() {
        sessionTask?.cancel()
    }
}

