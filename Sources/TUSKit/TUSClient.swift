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
    func didStartUpload(id: UUID, context: [String: String]?, client: TUSClient)
    /// `TUSClient` just finished an upload, returns the URL of the uploaded file.
    func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient)
    /// An upload failed. Returns an error. Could either be a TUSClientError or a networking related error.
    func uploadFailed(id: UUID, error: Error, context: [String: String]?, client: TUSClient)
    
    /// Receive an error related to files. E.g. The `TUSClient` couldn't store a file or remove a file.
    func fileError(error: TUSClientError, client: TUSClient)
    
    /// Get the progress of all ongoing uploads combined
    ///
    /// - Important: The total is based on active uploads, so it will lower once files are uploaded. This is because it's ambiguous what the total is. E.g. You can be uploading 100 bytes, after 50 bytes are uploaded, let's say you add 150 more bytes, is the total then 250 or 200? And what if the upload is done, and you add 50 more. Is the total 50 or 300? or 250?
    ///
    /// As a rule of thumb: The total will be highest on the start, a good starting point is to compare the progress against that number.
    @available(iOS 11.0, macOS 10.13, *)
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient)
    
    @available(iOS 11.0, macOS 10.13, *)
    /// Get the progress of a specific upload by id. The id is given when adding an upload and methods of this delegate.
    func progressFor(id: UUID, bytesUploaded: Int, totalBytes: Int, client: TUSClient)
}

public extension TUSClientDelegate {
    func progressFor(id: UUID, progress: Float, client: TUSClient) {
        // Optional
    }
}

protocol ProgressDelegate: AnyObject {
    @available(iOS 11.0, macOS 10.13, *)
    func progressUpdatedFor(metaData: UploadMetadata, totalUploadedBytes: Int)
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
    private var didStopAndCancel = false
    private let config: TUSConfig
    private let scheduler = Scheduler()
    private let api: TUSAPI
    /// Keep track of uploads and their id's
    private var uploads = [UUID: UploadMetadata]()
    private var progress = [UUID: Set<Range<Int>>]()
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
        self.api = TUSAPI(session: session)
        self.files = Files(storageDirectory: storageDirectory)
        
        scheduler.delegate = self
        removeFinishedUploads()
    }
    
    // MARK: - Starting and stopping
    
    /// Kick off the client to start uploading any locally stored files.
    /// - Returns: The pre-existing id's and contexts that are going to be uploaded. You can use this to continue former progress.
    @discardableResult
    public func start() -> [(UUID, [String: String]?)] {
        didStopAndCancel = false
        let metaData = scheduleStoredTasks()
        return metaData.map { metaData in
            (metaData.id, metaData.context)
        }
    }
    
    /// Stops the ongoing sessions, keeps the cache intact so you can continue uploading at a later stage.
    /// - Important: This method is `not` destructive. It only stops the client from running. If you want to avoid uploads to run again. Then please refer to `reset()` or `clearAllCache()`.
    public func stopAndCancelAll() {
        didStopAndCancel = true
        scheduler.cancelAll()
    }
    
    /// This will cancel all running uploads and clear the local cache.
    /// Expect errors passed to the delegate for canceled tasks.
    /// - Warning: This method is destructive and will remove any stored cache.
    /// - Throws: File related errors
    public func reset() throws {
        stopAndCancelAll()
        try clearAllCache()
    }
    
    // MARK: - Upload single file
    
    /// Upload data located at a url.  This file will be copied to a TUS directory for processing..
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameters:
    ///   - filePath: The path to a file on a local filesystem
    ///   - uploadURL: A custom URL to upload to. For if you don't want to use the default server url from the config. Will call the `create` on this custom url to get the definitive upload url.
    ///   - customHeaders: Any headers you want to add to an upload
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: ANn id
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadFileAt(filePath: URL, uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> UUID {
        didStopAndCancel = false
        do {
            let id = UUID()
            let destinationFilePath = try files.copy(from: filePath, id: id)
            try scheduleTask(for: destinationFilePath, id: id, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotCopyFile
        }
    }
    
    /// Upload data
    /// - Parameters:
    ///   - data: The data to be upload
    ///   - uploadURL: A custom URL to upload to. For if you don't want to use the default server url from the config. Will call the `create` on this custom url to get the definitive upload url.
    ///   - customHeaders: The headers to upload.
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: An id
    /// - Throws: TUSClientError
    @discardableResult
    public func upload(data: Data, uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> UUID {
        didStopAndCancel = false
        do {
            let id = UUID()
            let filePath = try files.store(data: data, id: id)
            try scheduleTask(for: filePath, id: id, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch {
            throw TUSClientError.couldNotStoreFile
        }
    }
    
    // MARK: - Upload multiple files
    
    /// Upload multiple files by giving their url.
    /// If you want a different uploadURL for each file, then please use `uploadFileAt(:)` individually.
    /// - Parameters:
    ///   - filePaths: An array of filepaths, represented by URLs
    ///   - uploadURL: The URL to upload to. Leave nil for the default URL.
    ///   - customHeaders: Any headers you want to add to the upload
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: An array of ids
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadFiles(filePaths: [URL], uploadURL:URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> [UUID] {
        try filePaths.map { filePath in
            try uploadFileAt(filePath: filePath, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
        }
    }
    
    /// Upload multiple files by giving their url.
    /// If you want a different uploadURL for each file, then please use `upload(data:)` individually.
    /// - Parameters:
    ///   - dataFiles: An array of data to be uploaded.
    ///   - uploadURL: The URL to upload to. Leave nil for the default URL.
    ///   - customHeaders: Any headers you want to add to the upload
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: An array of ids
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadMultiple(dataFiles: [Data], uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> [UUID] {
        try dataFiles.map { data in
            try upload(data: data, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
        }
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
            guard let metaData = try files.findMetadata(id: id) else {
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
            guard let metaData = try files.findMetadata(id: id) else {
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
    /// Note that the OS decides when uploading begins.
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
    private func scheduleTask(for storedFilePath: URL, id: UUID, uploadURL: URL?, customHeaders: [String: String], context: [String: String]?) throws {
        let filePath = storedFilePath
        
        func getSize() throws -> Int {
            let size = try filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Data(contentsOf: filePath).count
            
            guard size > 0 else {
                throw TUSClientError.fileSizeUnknown
            }
            
            return size
        }
        
        func makeMetadata() throws -> UploadMetadata {
            let size = try getSize()
            let url = uploadURL ?? config.server
            return UploadMetadata(id: id, filePath: filePath, uploadURL: url, size: size, customHeaders: customHeaders, mimeType: filePath.mimeType.nonEmpty, context: context)
        }
        
        let metaData = try makeMetadata()
        
        func trackUpload() {
            uploads[id] = metaData
        }
        
        guard let task = try taskFor(metaData: metaData, api: api, files: files, progressDelegate: self) else {
            assertionFailure("Could not find a task for metaData \(metaData)")
            return
        }
        
        try store(metaData: metaData)
        trackUpload()
        
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
    private func scheduleStoredTasks() -> [UploadMetadata] {
        do {
            let metaDataItems = try files.loadAllMetadata().filter({ metaData in
                // Only allow uploads where errors are below an amount
                metaData.errorCount <= retryCount && !metaData.isFinished
            })
            
            for metaData in metaDataItems {
                try scheduleTask(for: metaData)
            }
            
            return metaDataItems
        } catch {
            delegate?.fileError(error: TUSClientError.couldNotLoadData, client: self)
            return []
        }
    }
    
    /// Schedule a single task if needed. Will decide what task to schedule for the metaData.
    /// - Parameter metaData:The metaData the schedule.
    private func scheduleTask(for metaData: UploadMetadata) throws {
        guard let task = try taskFor(metaData: metaData, api: api, files: files, progressDelegate: self) else {
            throw TUSClientError.uploadIsAlreadyFinished
        }
        uploads[metaData.id] = metaData
        scheduler.addTask(task: task)
    }
    
}

extension TUSClient: SchedulerDelegate {
    func didFinishTask(task: ScheduledTask, scheduler: Scheduler) {
        switch task {
        case let task as UploadDataTask:
            handleFinishedUploadTask(task)
        case let task as StatusTask:
            handleFinishedStatusTask(task)
        case let task as CreationTask:
            handleCreationTask(task)
        default:
            break
        }
    }
    
    func handleCreationTask(_ creationTask: CreationTask) {
        creationTask.metaData.errorCount = 0
    }
    
    func handleFinishedStatusTask(_ statusTask: StatusTask) {
        statusTask.metaData.errorCount = 0 // We reset errorcounts after a succesful action.
        if statusTask.metaData.isFinished {
            _ = try? files.removeFileAndMetadata(statusTask.metaData) // If removing the file fails here, then it will be attempted again at next startup.
        }
    }
    
    func handleFinishedUploadTask(_ uploadTask: UploadDataTask) {
        uploadTask.metaData.errorCount = 0 // We reset errorcounts after a succesful action.
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
        
        uploads[uploadTask.metaData.id] = nil
        delegate?.didFinishUpload(id: uploadTask.metaData.id, url: url, context: uploadTask.metaData.context, client: self)
    }
    
    func didStartTask(task: ScheduledTask, scheduler: Scheduler) {
        guard let task = task as? UploadDataTask else { return }
        
        if task.metaData.uploadedRange == nil && task.metaData.errorCount == 0 {
            delegate?.didStartUpload(id: task.metaData.id, context: task.metaData.context, client: self)
        }
    }
    
    func onError(error: Error, task: ScheduledTask, scheduler: Scheduler) {
        let metaData: UploadMetadata
        switch task {
        case let task as CreationTask:
            metaData = task.metaData
        case let task as UploadDataTask:
            metaData = task.metaData
        case let task as StatusTask:
            metaData = task.metaData
        default:
            fatalError("Unsupported task errored")
        }
        
        if didStopAndCancel {
            return
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
            delegate?.uploadFailed(id: metaData.id, error: error, context: metaData.context, client: self)
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
func taskFor(metaData: UploadMetadata, api: TUSAPI, files: Files, progressDelegate: ProgressDelegate? = nil) throws -> ScheduledTask? {
    guard !metaData.isFinished else {
        return nil
    }
    
    if let remoteDestination = metaData.remoteDestination {
        let statusTask = StatusTask(api: api, remoteDestination: remoteDestination, metaData: metaData, files: files, chunkSize: TUSClient.chunkSize)
        statusTask.progressDelegate = progressDelegate
        return statusTask
    } else {
        let creationTask = try CreationTask(metaData: metaData, api: api, files: files, chunkSize: TUSClient.chunkSize)
        creationTask.progressDelegate = progressDelegate
        return creationTask
    }
}

extension TUSClient: ProgressDelegate {
    
    @available(iOS 11.0, macOS 10.13, *)
    func progressUpdatedFor(metaData: UploadMetadata, totalUploadedBytes: Int) {
        delegate?.progressFor(id: metaData.id, bytesUploaded: totalUploadedBytes, totalBytes: metaData.size, client: self)

        var totalBytesUploaded: Int = 0
        var totalSize: Int = 0
        for (_, metaData) in uploads {
            totalBytesUploaded += metaData.uploadedRange?.count ?? 0
            totalSize += metaData.size
        }

        delegate?.totalProgress(bytesUploaded: totalBytesUploaded, totalBytes: totalSize, client: self)
    }
}
