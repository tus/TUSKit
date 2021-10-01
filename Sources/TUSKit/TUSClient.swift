//
//  TUSClient.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation
import BackgroundTasks

/// Implement this delegate to receive updates from the TUSClient
public protocol TUSClientDelegate: AnyObject {
    /// TUSClient is starting an upload
    func didStartUpload(id: UUID, client: TUSClient)
    /// `TUSClient` just finished an upload, returns the URL of the uploaded file.
    func didFinishUpload(id: UUID, url: URL, client: TUSClient)
    /// An upload failed. Returns an error. Could either be a TUSClientError or a networking related error.
    func uploadFailed(id: UUID, error: Error, client: TUSClient)
    /// Receive an error related to files. E.g. The `TUSClient` couldn't store a file or remove a file.
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
    public static let uploadIsAlreadyFinished = TUSClientError(code: 11)
    public static let couldNotRetryUpload = TUSClientError(code: 12)
    public static let couldnotRemoveFinishedUploads = TUSClientError(code: 13)
    public static let receivedUnexpectedOffset = TUSClientError(code: 14)
}

/// The TUSKit client.
/// Please refer to the Readme.md on how to use this type.
public final class TUSClient {
    
    /// The number of uploads that the TUSClient will try to complete.
    public var remainingUploads: Int {
        uploads.count
    }
    
    static let chunkSize: Int = 500 * 1024
    
    /// How often to try an upload if it fails. A retryCount of 2 means 3 total uploads max. (1 initial upload, and on repeated failure, 2 more retries.)
    private let retryCount = 2
    
    public let sessionIdentifier: String
    private let files: Files
    private let config: TUSConfig
    private let scheduler = Scheduler()
    private let api: TUSAPI
    /// Keep track of uploads and their id's
    private var uploads = [URL: UUID]()
    public weak var delegate: TUSClientDelegate?
    
#if os(iOS)
    @available(iOS 13.0, *)
    private lazy var backgroundClient: TUSBackground = {
        return TUSBackground(scheduler: BGTaskScheduler.shared, api: api, files: files)
    }()
#endif
    
    /// Initialize a TUSClient
    /// - Parameters:
    ///   - config: A config
    ///   - sessionIdentifier: An identifier to know which TUSClient calls delegate methods, also used for URLSession configurations.
    ///   - storageDirectory: A directory to store local files for uploading and continuing uploads. Leave nil to use the documents dir. Pass a relative path (e.g. "TUS" or "/TUS" or "/Uploads/TUS") for a relative directory inside the documents directory.
    ///   You can also pass an absolute path, e.g. "file://uploads/TUS"
    ///   - session: A URLSession you'd like to use. Will default to `URLSession.shared`.
    public init(config: TUSConfig, sessionIdentifier: String, storageDirectory: URL?, session: URLSession = URLSession.shared) {
        self.config = config
        self.sessionIdentifier = sessionIdentifier
        self.api = TUSAPI(session: session, uploadURL: config.server)
        self.files = Files(storageDirectory: storageDirectory)
        
        scheduler.delegate = self
        removeFinishedUploads()
    }
    
    // MARK: - Starting and stopping
    
    /// Kick off the client to start uploading any locally stored files.
    public func start() {
        scheduleStoredTasks()
    }
    
    /// Stops the ongoing sessions, keeps the cache intact so you can continue uploading at a later stage.
    /// - Important: This method is `not` destructive. If you want to stop everything (as a reset), please use `stopAndCancelAllUploads`.
    public func stop() {
        scheduler.cancelAll()
    }
    
    /// This will cancel all running uploads and clear the local cache.
    /// Expect errors passed to the delegate for canceled tasks.
    /// - Warning: This method is destructive and will remove any stored cache.
    /// - Throws: File related errors
    public func stopAndCancelAllUploads() throws {
        scheduler.cancelAll()
        try clearAllCache()
        // TODO: Maybe not needed if tasks cancel already
//        uploads = [:]
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
            let destinationFilePath = try files.copy(from: filePath, id: id)
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
            let filePath = try files.store(data: data, id: id)
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
    /// - Important:This will clear the storage directory that you supplied.
    /// - Important:Don't call this while the client is active. Only between uploading sessions.
    /// - Throws: TUSClientError if a file is found but couldn't be deleted. Or if files couldn't be loaded.
    public func clearAllCache() throws {
        do {
            try files.clearCacheInStorageDirectory()
        } catch {
            throw TUSClientError.couldNotDeleteFile
        }
    }
    
    /// Remove a cache related to an id
    /// - Important:Don't call this while the client is active. Only between uploading sessions.  Or you get undefined behavior.
    /// - Parameter id: The id of a (scheduled) upload that you wish to delete.
    /// - Returns: A bool whether or not the upload was found and deleted.
    /// - Throws: TUSClientError if a file is found but couldn't be deleted. Or if files couldn't be loaded.
    @discardableResult
    public func removeCacheFor(id: UUID) throws -> Bool {
        do {
            let metaData = try files.loadAllMetadata().first(where: { metaData in
                metaData.id == id
            })
            guard let metaData = metaData else {
                return false
            }
            
            try files.removeFileAndMetadata(metaData)
            return true
        } catch {
            throw TUSClientError.couldNotDeleteFile
        }
    }
   
    /// Retry a failed upload. Note that `TUSClient` already has an internal retry mechanic before it reports an upload as failure.
    /// If however, you like to retry an upload at a later stage, you can use this method to trigger the upload again.
    /// - Important: Don't retry an upload while it's still being uploaded. You get undefined behavior.
    /// - Parameter id: The id of an upload. Received when starting an upload, or via the `TUSClientDelegate`.
    /// - Returns: True if the id is found. False if it's not found
    /// - Throws: `TUSClientError.couldNotRetryUpload` if it can't load an the file. Or file related errors.
    @discardableResult
    public func retry(id: UUID) throws -> Bool {
        do {
            let metaData = try files.loadAllMetadata().first(where: { metaData in
                metaData.id == id
            })
            guard let metaData = metaData else {
                return false
            }
            
            metaData.errorCount = 0
            
            try scheduleTask(for: metaData)
            return true
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotRetryUpload
        }
    }
    
    /// When your app moves to the background, you can call this method to schedule background tasks to perform.
    /// This will signal the OS to upload files when appropriate (e.g. when a phone is on a charger and on Wifi).
    /// Note that the OS decided when uploading begins.
#if os(iOS)
    @available(iOS 13.0, *)
    public func scheduleBackgroundTasks() {
        backgroundClient.scheduleBackgroundTasks()
    }
#endif
    
    /// Return the id's all failed uploads. Good to check after launch or after background processing for example, to handle them at a later stage.
    /// - Returns: An id's array of erronous uploads.
    public func failedUploadIds() throws -> [UUID] {
        try files.loadAllMetadata().compactMap { metaData in
            if metaData.errorCount > retryCount {
                return metaData.id
            } else {
                return nil
            }
        }
    }
    
    // MARK: - Private
    
    /// Ceck for any uploads that are finished and remove them from the cache.
    private func removeFinishedUploads() {
        do {
            let metaDataList = try files.loadAllMetadata()
                .filter { metaData in
                    metaData.size == metaData.uploadedRange?.count
                }
            
            for metaData in metaDataList {
                try files.removeFileAndMetadata(metaData)
            }
        } catch {
            delegate?.fileError(error: TUSClientError.couldnotRemoveFinishedUploads, client: self)
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

        let task = try CreationTask(metaData: metaData, api: api, files: files, chunkSize: type(of: self).chunkSize)
        scheduler.addTask(task: task)
    }
    
    /// Store UploadMetadata to sdisk
    /// - Parameter metaData: The `UploadMetadata` to store.
    /// - Throws: TUSClientError.couldNotStoreFileMetadata
    private func store(metaData: UploadMetadata) throws {
        do {
            // We store metadata here, so it's saved even if this job doesn't run this session. (Only created, doesn't mean it will run)
            try files.encodeAndStore(metaData: metaData)
        } catch {
            throw TUSClientError.couldNotStoreFileMetadata
        }
    }
    
    /// Check which uploads aren't finished. Load them from a store and turn these into tasks.
    private func scheduleStoredTasks() {
        do {
            let metaDataItems = try files.loadAllMetadata().filter({ metaData in
                // Only allow uploads where errors are below an amount
                metaData.errorCount <= retryCount && !metaData.isFinished
            })
            
            for metaData in metaDataItems {
                try scheduleTask(for: metaData)
            }
        } catch {
            // TODO: Return error, can't load from store
        }
    }
    
    /// Schedule a single task if needed. Will decide what task to schedule for the metaData.
    /// - Parameter metaData:The metaData the schedule.
    private func scheduleTask(for metaData: UploadMetadata) throws {
        guard let task = try taskFor(metaData: metaData, api: api, files: files) else {
            throw TUSClientError.uploadIsAlreadyFinished
        }
        uploads[metaData.filePath] = metaData.id
        scheduler.addTask(task: task)
    }
    
}

extension TUSClient: SchedulerDelegate {
    func didFinishTask(task: Task, scheduler: Scheduler) {
        switch task {
        case let task as UploadDataTask:
            handleFinishedUploadTask(task)
        case let task as StatusTask:
            handleFinishedStatusTask(task)
        default:
            break
        }
    }
    
    func handleFinishedStatusTask(_ statusTask: StatusTask) {
        if statusTask.metaData.isFinished {
            _ = try? files.removeFileAndMetadata(statusTask.metaData) // If removing the file fails here, then it will be attempted again at next startup.
        }
    }
    
    func handleFinishedUploadTask(_ uploadTask: UploadDataTask) {
        guard uploadTask.metaData.isFinished else { return }
        
        do {
            try files.removeFileAndMetadata(uploadTask.metaData)
        } catch {
            delegate?.fileError(error: TUSClientError.couldNotDeleteFile, client: self)
        }
        
        guard let url = uploadTask.metaData.remoteDestination else {
            assertionFailure("Somehow uploaded task did not have a url")
            return
        }
        
        guard let id = uploads[uploadTask.metaData.filePath] else {
            assertionFailure("Somehow task \(uploadTask) did not have an id for filePath \(uploadTask.metaData.filePath)")
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
            assertionFailure("Starting task \(task) Somehow the filePath doesn't have an associated id, uploads are \(uploads)")
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
            try files.encodeAndStore(metaData: metaData)
        } catch {
            delegate?.fileError(error: TUSClientError.couldNotStoreFileMetadata, client: self)
        }
        
        let canRetry = metaData.errorCount <= retryCount
        if canRetry {
            scheduler.addTask(task: task)
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

/// Decide which task to create based on metaData.
/// - Parameter metaData: The `UploadMetadata` for which to create a `Task`.
/// - Returns: The task that has to be performed for the relevant metaData. Will return nil if metaData's file is already uploaded / finished. (no task needed).
func taskFor(metaData: UploadMetadata, api: TUSAPI, files: Files) throws -> Task? {
    guard !metaData.isFinished else {
        return nil
    }
    
    if let remoteDestination = metaData.remoteDestination {
        return StatusTask(api: api, remoteDestination: remoteDestination, metaData: metaData, files: files, chunkSize: TUSClient.chunkSize)
    } else {
        return try CreationTask(metaData: metaData, api: api, files: files)
    }
}

