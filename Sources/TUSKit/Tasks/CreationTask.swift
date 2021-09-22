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
    let api: TUSAPI
    let chunkSize: Int?
    var metaData: UploadMetadata
    let customHeaders: [String: String]

    init(metaData: UploadMetadata, api: TUSAPI, customHeaders: [String: String]?, chunkSize: Int? = nil) throws {
        self.metaData = metaData
        self.api = api
        self.chunkSize = chunkSize
        self.customHeaders = customHeaders ?? [:]
    }
    
    func run(completed: @escaping TaskCompletion) {
        api.create(metaData: metaData) { [unowned self] result in
            // File is created remotely. Now start first datatask.

            do {
                
                let remoteDestination = try result.get()
                metaData.remoteDestination = remoteDestination
                try Files.encodeAndStore(metaData: metaData)
                let task: UploadDataTask
                if let chunkSize = chunkSize {
                    task = try UploadDataTask(api: api, metaData: metaData, range: 0..<chunkSize)
                } else {
                    task = try UploadDataTask(api: api, metaData: metaData)
                }
                completed(.success([task]))
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotCreateFileOnServer))
            }
            
        }
    }
}
