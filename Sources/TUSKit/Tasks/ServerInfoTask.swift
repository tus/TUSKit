//
//  ServerInfoTask.swift
//  
//
//  Created by 𝗠𝗮𝗿𝘁𝗶𝗻 𝗟𝗮𝘂 on 2023-02-20.
//

import Foundation

/// A `ServerInfoTask` fetches the server information. It automatically retrieves server information to
/// further help determine the type of support for the next task
final class ServerInfoTask: IdentifiableTask {
    
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
    
    func run(completed: @escaping TaskCompletion) {
        if didCancel { return }
        let serverURL = metaData.uploadURL
        sessionTask = api.serverInfo(server: serverURL) { [weak self] result in
            guard let self = self else { return }
            
            // Getting rid of self. in this closure
            let metaData = self.metaData
            let files = self.files
            let chunkSize = self.chunkSize
            let api = self.api
            let progressDelegate = self.progressDelegate
            
            do {
                let serverInfo = try result.get()
                if let extensions = serverInfo.extensions {
                    metaData.supportedExtensions = extensions
                    if extensions.contains(.creation) {
                        // 创建 CreateTask
                        let task = try CreationTask(metaData: metaData, api: api, files: files, chunkSize: chunkSize)
                        task.progressDelegate = progressDelegate
                        completed(.success([task]))
                    }
                } else {
                    completed(.failure(TUSClientError.couldNotFetchServerInfo))
                }
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotFetchServerInfo))
            }
        }
    }
    
    func cancel() {
        didCancel = true
        sessionTask?.cancel()
    }
}
