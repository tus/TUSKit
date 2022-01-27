//
//  StatusTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// A `StatusTask` fetches the status of an upload. It fetches the offset from we can continue uploading, and then makes a possible uploadtask.
final class StatusTask: ScheduledTask {
    
    weak var progressDelegate: ProgressDelegate?
    let api: TUSAPI
    let files: Files
    let remoteDestination: URL
    let metaData: UploadMetadata
    let chunkSize: Int
    private var didCancel: Bool = false
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
        if didCancel { return }
        sessionTask = api.status(remoteDestination: remoteDestination) { [weak self] result in
            guard let self = self else { return }
            // Getting rid of self. in this closure
            let metaData = self.metaData
            let files = self.files
            let chunkSize = self.chunkSize
            let api = self.api
            let progressDelegate = self.progressDelegate
            
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
                    let nextRange = offset..<min((offset + chunkSize), metaData.size)
                    
                    let task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange)
                    task.progressDelegate = progressDelegate
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
        didCancel = true
        sessionTask?.cancel()
    }
}

