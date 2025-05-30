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

    private let queue = DispatchQueue(label: "com.tuskit.creationtask")

    init(metaData: UploadMetadata, api: TUSAPI, files: Files, chunkSize: Int? = nil) throws {
        self.metaData = metaData
        self.api = api
        self.files = files
        self.chunkSize = chunkSize
    }
    
    func run(completed: @escaping TaskCompletion) {
        queue.async {
            if self.didCancel { return }

            self.sessionTask = self.api.create(metaData: self.metaData) { [weak self] result in
                guard let self else { return }

                // File is created remotely. Now start first datatask.
                self.queue.async {
                    let metaData = self.metaData
                    let files = self.files
                    let chunkSize = self.chunkSize
                    let api = self.api
                    let progressDelegate = self.progressDelegate

                    do {
                        let remoteDestination = try result.get()
                        metaData.remoteDestination = remoteDestination
                        try files.encodeAndStore(metaData: metaData)
                        let task: UploadDataTask
                        if let chunkSize = chunkSize {
                            let newRange = 0..<chunkSize
                            task = try UploadDataTask(api: api, metaData: metaData, files: files, range: newRange)
                        } else {
                            task = try UploadDataTask(api: api, metaData: metaData, files: files)
                        }
                        task.progressDelegate = progressDelegate
                        if self.didCancel {
                            completed(.failure(TUSClientError.taskCancelled))
                        } else {
                            completed(.success([task]))
                        }
                    } catch let error as TUSClientError {
                        completed(.failure(error))
                    } catch {
                        completed(.failure(TUSClientError.couldNotCreateFileOnServer))
                    }
                }
            }
        }
    }
    
    func cancel() {
        queue.async {
            self.didCancel = true
            self.sessionTask?.cancel()
        }
    }
}
