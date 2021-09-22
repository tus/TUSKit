//
//  TUSClient.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

public protocol TUSClientDelegate: AnyObject {
    func didStartUpload(id: UUID, client: TUSClient)
    func didFinishUpload(id: UUID, url: URL, client: TUSClient)
    func uploadFailed(id: UUID, error: Error, client: TUSClient)
    func fileError(error: TUSClientError, client: TUSClient)
}

/// The errors that are passed from TUSClient
public struct TUSClientError: Error {
    // Maintenance: We use static lets on a struct, instead of an enum, so that adding new cases won't break stability.
    // Alternatively we can ask users to always use `unknown default`, but we can't guarantee that everyone will use that.
    
    let code: Int

    public static let couldNotCopyFile = TUSClientError(code: 1)
    public static let couldNotStoreFile = TUSClientError(code: 2)
    public static let fileSizeUnknown = TUSClientError(code: 3)
    public static let couldNotLoadData = TUSClientError(code: 4)
    public static let couldNotStoreFileMetadata = TUSClientError(code: 5)
    public static let couldNotCreateFileOnServer = TUSClientError(code: 6)
    public static let couldNotUploadFile = TUSClientError(code: 7)
    public static let couldNotGetFileStatus = TUSClientError(code: 8)
    public static let fileSizeMismatchWithServer = TUSClientError(code: 9)
    public static let couldNotDeleteFile = TUSClientError(code: 10)
}


/// The TUSKit client.
///
/// ## Example
///
///     let client = TUSClient(config: TUSConfig(server: liveDemoPath))
///
public final class TUSClient {
    
    /// How often to try an upload if it fails. A retryCount of 2 means 3 total uploads max. (1 initial upload, and on repeated failure, 2 more retries.)
    private let retryCount = 2
    
    public let sessionIdentifier: String
    private let config: TUSConfig
    private let scheduler = Scheduler()
    private let storageDirectory: URL
    private let api: TUSAPI
    /// Keep track of uploads and their id's
    private var uploads = [URL: UUID]()
    public weak var delegate: TUSClientDelegate?
    
    public var remainingUploads: Int {
        uploads.count
    }
    
    /// Initialize a TUSClient
    /// - Parameters:
    ///   - config: A config
    ///   - sessionIdentifier: An identifier to know which TUSClient calls delegate methods, also used for URLSession configurations.
    ///   - storageDirectory: A directory to save files to, if it isn't passed, the documents directory will be used. Prefer to use reverse DNS notation, such as io.tus, so that you have a unique folder for your app
    public convenience init(config: TUSConfig, sessionIdentifier: String, storageDirectory: URL) {
        self.init(config: config, sessionIdentifier: sessionIdentifier, storageDirectory: storageDirectory, network: URLSession.shared)
    }
    
    /// Internal initializer to gain access to the Network protocol. To allow for mocking yet keeping the protocol shielded from public API.
    init(config: TUSConfig, sessionIdentifier: String, storageDirectory: URL, network: Network) {
        self.config = config
        self.sessionIdentifier = sessionIdentifier
        self.storageDirectory = storageDirectory
        self.api = TUSAPI(uploadURL: config.server, network: network)
        
        start()
    }

    // MARK: - Upload single file
    
    /// Upload data located at a url.  This file will be copied to a TUS directory for processing..
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameter filePath: The path to a file on a local filesystem.
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadFileAt(filePath: URL, customHeaders: [String: String] = [:]) throws -> UUID {
        do {
            let id = UUID()
            let destinationFilePath = try Files.copy(from: filePath, id: id)
            try scheduleCreationTask(for: destinationFilePath, id: id, customHeaders: customHeaders)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotCopyFile
        }
    }
    
    /// Upload data
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    @discardableResult
    public func upload(data: Data, customHeaders: [String: String] = [:]) throws -> UUID {
        do {
            let id = UUID()
            let filePath = try Files.store(data: data, id: id)
            try scheduleCreationTask(for: filePath, id: id, customHeaders: customHeaders)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotStoreFile
        }
    }
    
    // MARK: - Upload multiple files
    
    /// Upload multiple files by giving their url
    /// - Parameter filePaths: An array of filepaths, represented by URLs
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadFiles(filePaths: [URL], customHeaders: [String: String] = [:]) throws -> [UUID] {
        var ids = [UUID]()
        for filePath in filePaths {
            try ids.append(uploadFileAt(filePath: filePath, customHeaders: customHeaders))
        }
        return ids
    }
    
    /// Upload multiple data files
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadMultiple(dataFiles: [Data], customHeaders: [String: String] = [:]) throws -> [UUID] {
        var ids = [UUID]()
        for data in dataFiles {
            try ids.append(upload(data: data, customHeaders: customHeaders))
        }
        return ids
    }
    
    // MARK: - Cache
    
    /// Throw away all files.
    /// - Important:Don't call this while the client is active. Only between uploading sessions.
    /// - Throws: TUSClientError if a file is found but couldn't be deleted. Or if files couldn't be loaded.
    public func clearAllCache() throws {
        do {
            try Files.clearTUSDirectory()
        } catch {
            throw TUSClientError.couldNotDeleteFile
        }
    }
    
    /// Remove a cache related to an id
    /// - Important:Don't call this while the client is active. Only between uploading sessions.
    /// - Parameter id: The id of a (scheduled) upload that you wish to delete.
    /// - Returns: A bool whether or not the upload was found and deleted.
    /// - Throws: TUSClientError if a file is found but couldn't be deleted. Or if files couldn't be loaded.
    @discardableResult
    public func removeCacheFor(id: UUID) throws -> Bool {
        do {
            let metaData = try Files.loadAllMetadata().first(where: { metaData in
                                                                      metaData.id == id
                                                                  })
            guard let metaData = metaData else {
                return false
            }
            
            try Files.removeFileAndMetadata(metaData)
            return true
        } catch {
            throw TUSClientError.couldNotDeleteFile
        }
    }
    
    // MARK: - Private
    
    /// Kick off the client to configure itself and upload any remaining files.
    private func start() {
        scheduler.delegate = self
        Files.TUSDirectory = storageDirectory.relativePath
        
        removeFinishedUploads()
        scheduleStoredTasks()
    }
    
    /// Ceck for any uploads that are finished and remove them from the cache.
    private func removeFinishedUploads() {
        do {
            try Files.loadAllMetadata()
              .filter { metaData in
                  metaData.size == metaData.uploadedRange?.count
              }.forEach(Files.removeFileAndMetadata)
        } catch {
            // log
            print("Could not clear / remove old uploads")
        }
    }
    
    /// Upload a file at the URL. Will not copy the path.
    /// - Parameter storedFilePath: The path where the file is stored for processing.
    private func scheduleCreationTask(for storedFilePath: URL, id: UUID, customHeaders: [String: String]) throws {
        let filePath = storedFilePath
        
        func getSize() throws -> Int {
            let size = try filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Data(contentsOf: filePath).count
            
            guard size > 0 else {
                throw TUSClientError.fileSizeUnknown
            }
            
            return size
        }
        
        let size = try getSize()
        
        let metaData = UploadMetadata(id: id, filePath: filePath, size: size, customHeaders: customHeaders, mimeType: filePath.mimeType.nonEmpty)
        try store(metaData: metaData)
        
        uploads[filePath] = id

        let task = try CreationTask(metaData: metaData, api: api, customHeaders: customHeaders)
        scheduler.addTask(task: task)
    }
    
    private func store(metaData: UploadMetadata) throws {
        do {
            // We store metadata here, so it's saved even if this job doesn't run this session. (Only created, doesn't mean it will run)
            try Files.encodeAndStore(metaData: metaData)
        } catch {
            throw TUSClientError.couldNotStoreFileMetadata
        }
    }
    
    /// Check which uploads aren't finished. Load them from a store and turn these into tasks.
    private func scheduleStoredTasks() {
        func tasksFrom(metaData: [UploadMetadata]) throws -> [Task] {
            // Improvement: Doesn't group a single upload into multiple.
            // Once concurrent uploading comes into play. Return [[Task]] so
            return try metaData.map { metaData in
                if let remoteDestination = metaData.remoteDestination {
                    return StatusTask(api: api, remoteDestination: remoteDestination, metaData: metaData)
                } else {
                    return try CreationTask(metaData: metaData, api: api, customHeaders: metaData.customHeaders)
                }
            }
        }
        
        do {
            let metaDataItems = try Files.loadAllMetadata().filter({ metaData in
                // Only allow uploads where errors are below an amount
                metaData.errorCount <= retryCount
            })
            
            for metaData in metaDataItems {
                uploads[metaData.filePath] = metaData.id
            }
            let tasks = try tasksFrom(metaData: metaDataItems)
            scheduler.addTasks(tasks: tasks)
        } catch {
            // TODO: Return error, can't load from store
        }
    }
}

extension TUSClient: SchedulerDelegate {
    func didFinishTask(task: Task, scheduler: Scheduler) {
        guard  let uploadTask = task as? UploadDataTask else {
            return
        }
        
        do {
            try Files.removeFileAndMetadata(uploadTask.metaData)
        } catch {
            delegate?.fileError(error: TUSClientError.couldNotDeleteFile, client: self)
        }
        
        guard let url = uploadTask.metaData.remoteDestination else {
            assertionFailure("Somehow uploaded task did not have a url")
            return
        }
        
        guard let id = uploads[uploadTask.metaData.filePath] else {
            assertionFailure("Somehow task \(task) did not have an id")
            delegate?.didFinishUpload(id: UUID(), url: url, client: self)
            return
        }
        
        uploads[uploadTask.metaData.filePath] = nil
        delegate?.didFinishUpload(id: id, url: url, client: self)
    }
    
    func didStartTask(task: Task, scheduler: Scheduler) {
        // TODO: Use logger
        guard let task = task as? UploadDataTask else { return }
        guard let id = uploads[task.metaData.filePath] else {
            assertionFailure("Somehow the filePath doesn't have an associated id")
            // TODO: Log assertion?
            delegate?.didStartUpload(id: UUID(), client: self)
            return
        }
        delegate?.didStartUpload(id: id, client: self)
    }
    
    func onError(error: Error, task: Task, scheduler: Scheduler) {
        let id: UUID
        let metaData: UploadMetadata
        switch task {
        case let task as CreationTask:
            id = task.metaData.id
            metaData = task.metaData
        case let task as UploadDataTask:
            id = task.metaData.id
            metaData = task.metaData
        case let task as StatusTask:
            id = task.metaData.id
            metaData = task.metaData
        default:
            fatalError("Unsupported task errored")
        }
        
        metaData.errorCount += 1
        do {
            try Files.encodeAndStore(metaData: metaData)
        } catch {
            delegate?.fileError(error: TUSClientError.couldNotStoreFileMetadata, client: self)
        }
        
        if metaData.errorCount <= retryCount {
            scheduler.addTask(task: task) // Let's retry
        } else { // Exhausted all retries, reporting back as failure.
            delegate?.uploadFailed(id: id, error: error, client: self)
        }
    }
}

private extension String {
    
    /// Turn an empty string in a nil string, otherwise return self
    var nonEmpty: String? {
        if self.isEmpty {
            return nil
        } else {
            return self
        }
    }
}
