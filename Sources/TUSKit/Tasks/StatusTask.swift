//
//  StatusTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// A `StatusTask` fetches the status of an upload. It fetches the offset from we can continue uploading, and then makes a possible uploadtask.
final class StatusTask: IdentifiableTask {
    
    // MARK: - IdentifiableTask
    
    var id: UUID {
        metaData.id
    }
    
    weak var progressDelegate: ProgressDelegate?
    let api: TUSAPI
    let files: Files
    let remoteDestination: URL
    let metaData: UploadMetadata
    let chunkSize: Int?
    private let headerGenerator: HeaderGenerator
    private var didCancel: Bool = false
    weak var sessionTask: URLSessionDataTask?

    private let queue = DispatchQueue(label: "com.tuskit.statustask")

    init(api: TUSAPI, remoteDestination: URL, metaData: UploadMetadata, files: Files, chunkSize: Int?, headerGenerator: HeaderGenerator) {
        self.api = api
        self.remoteDestination = remoteDestination
        self.metaData = metaData
        self.files = files
        self.chunkSize = chunkSize
        self.headerGenerator = headerGenerator
    }
    
    func run(completed: @escaping TaskCompletion) {
        // Improvement: On failure, try uploading from the start. Create creationtask.
        queue.async {
            if self.didCancel { return }

            self.headerGenerator.resolveHeaders(for: self.metaData) { [weak self] customHeaders in
                guard let self else { return }

                self.queue.async {
                    if self.didCancel { return }

                    self.sessionTask = self.api.status(remoteDestination: self.remoteDestination, headers: customHeaders) { [weak self] result in
                        guard let self else { return }

                        self.queue.async {
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
                                    // If the task has been canceled
                                    // we don't continue to create subsequent UploadDataTasks
                                    if self.didCancel {
                                        throw TUSClientError.taskCancelled
                                    }

                                    let nextRange: Range<Int>
                                    if let chunkSize {
                                        nextRange  = offset..<min((offset + chunkSize), metaData.size)
                                    } else {
                                        nextRange = offset..<metaData.size
                                    }

                                    let task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange, headerGenerator: self.headerGenerator)
                                    task.progressDelegate = progressDelegate
                                    completed(.success([task]))
                                }
                            } catch let error as TUSClientError {
                                completed(.failure(error))
                            } catch {
                                completed(.failure(TUSClientError.couldNotGetFileStatus(underlyingError: error)))
                            }
                        }
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
