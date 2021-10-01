//
//  CreationTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// `CreationTask` Prepares the server for a file upload.
/// The server will return a path to upload to.
final class CreationTask: Task {
    var metaData: UploadMetadata
    let api: TUSAPI
    let files: Files
    let chunkSize: Int?
    weak var sessionTask: URLSessionDataTask?

    init(metaData: UploadMetadata, api: TUSAPI, files: Files, chunkSize: Int? = nil) throws {
        self.metaData = metaData
        self.api = api
        self.files = files
        self.chunkSize = chunkSize
    }
    
    func run(completed: @escaping TaskCompletion) {
        sessionTask = api.create(metaData: metaData) { [unowned self] result in
            // File is created remotely. Now start first datatask.

            do {
                
                let remoteDestination = try result.get()
                metaData.remoteDestination = remoteDestination
                try files.encodeAndStore(metaData: metaData)
                let task: UploadDataTask
                if let chunkSize = chunkSize {
                    let newRange = 0..<min(chunkSize, metaData.size)
                    task = try UploadDataTask(api: api, metaData: metaData, files: files, range: newRange)
                } else {
                    task = try UploadDataTask(api: api, metaData: metaData, files: files)
                }
                completed(.success([task]))
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotCreateFileOnServer))
            }
            
        }
    }
    
    func cancel() {
        sessionTask?.cancel()
    }
}
