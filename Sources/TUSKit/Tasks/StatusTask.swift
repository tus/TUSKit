//
//  StatusTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// A `StatusTask` fetches the status of an upload. It fetches the offset from we can continue uploading, and then makes a possible uploadtask.
actor StatusTask: IdentifiableTask {
    
    // MARK: - IdentifiableTask
    
    nonisolated var id: UUID {
        metaData.id
    }
    
    nonisolated(unsafe) weak var progressDelegate: ProgressDelegate?
    let api: TUSAPI
    let files: Files
    let remoteDestination: URL
    nonisolated let metaData: UploadMetadata
    let chunkSize: Int?
    private var didCancel: Bool = false
    weak var sessionTask: URLSessionDataTask?
    
    init(api: TUSAPI, remoteDestination: URL, metaData: UploadMetadata, files: Files, chunkSize: Int?) {
        self.api = api
        self.remoteDestination = remoteDestination
        self.metaData = metaData
        self.files = files
        self.chunkSize = chunkSize
    }
    
    func run() async throws -> [any ScheduledTask] {
        
        
        do {
#warning("We used to grab a session task here to support cancellation")
            let status = try await api.status(
                remoteDestination: remoteDestination,
                headers: metaData.customHeaders
            )
            
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
                return []
            } else {
                // If the task has been canceled
                // we don't continue to create subsequent UploadDataTasks
                if self.didCancel {
                    return []
                }
                
                let nextRange: Range<Int>
                if let chunkSize {
                   nextRange  = offset..<min((offset + chunkSize), metaData.size)
                } else {
                    nextRange = offset..<metaData.size
                }
                
                let task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange)
                task.progressDelegate = progressDelegate
                return [task]
            }
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotGetFileStatus
        }
    }
    
    func cancel() {
        didCancel = true
        sessionTask?.cancel()
    }
}

