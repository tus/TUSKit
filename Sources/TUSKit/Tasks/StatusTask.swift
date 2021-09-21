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
    let remoteDestination: URL
    let metaData: UploadMetadata
    
    init(api: TUSAPI, remoteDestination: URL, metaData: UploadMetadata) {
        self.api = api
        self.remoteDestination = remoteDestination
        self.metaData = metaData
    }
    
    func run(completed: @escaping TaskCompletion) {
        // Improvement: On failure, try uploading from the start. Create creationtask.
        api.status(remoteDestination: remoteDestination) { [unowned self] result in
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
                
                if offset == metaData.size {
                    completed(.success([]))
                } else {
                    let task = try UploadDataTask(api: api, metaData: metaData, range: offset..<metaData.size)
                    completed(.success([task]))
                }
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotGetFileStatus))
            }
            
        }
    }
}

