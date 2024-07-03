//
//  CreationTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// `CreationTask` Prepares the server for a file upload.
/// The server will return a path to upload to.
final class CreationTask: IdentifiableTask {
    
    // MARK: - IdentifiableTask
    
    var id: UUID {
        metaData.id
    }
    
    weak var progressDelegate: ProgressDelegate?
    let metaData: UploadMetadata
    
    private let api: TUSAPI
    private let files: Files
    private let chunkSize: Int?
    private var didCancel: Bool = false
    private weak var sessionTask: URLSessionDataTask?

    init(metaData: UploadMetadata, api: TUSAPI, files: Files, chunkSize: Int? = nil) throws {
        self.metaData = metaData
        self.api = api
        self.files = files
        self.chunkSize = chunkSize
    }
    
    func run() async throws -> [any ScheduledTask] {
        guard !didCancel else { return [] }
        
        #warning("We used to grab a session task here to support cancellation")
        do {
            let remoteDestination = try await api.create(metaData: metaData)
            
            metaData.remoteDestination = remoteDestination
            try files.encodeAndStore(metaData: metaData)
            let task: UploadDataTask
            if let chunkSize = chunkSize {
                let newRange = 0..<min(chunkSize, metaData.size)
                task = try UploadDataTask(api: api, metaData: metaData, files: files, range: newRange)
            } else {
                task = try UploadDataTask(api: api, metaData: metaData, files: files)
            }
            task.progressDelegate = progressDelegate
            if self.didCancel {
                throw TUSClientError.couldNotCreateFileOnServer
            } else {
                return [task]
            }
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotCreateFileOnServer
        }
    }
    
    func cancel() {
        didCancel = true
        sessionTask?.cancel()
    }
}
