//
//  TUSClient.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation
import BackgroundTasks
#if os(iOS)
import MobileCoreServices
#endif

/// Implement this delegate to receive updates from the TUSClient
public protocol TUSClientDelegate: AnyObject {
    /// TUSClient initialized an upload
    func didInitializeUpload(id: UUID, context: [String: String]?, client: TUSClient)
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
    func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient)
}

public extension TUSClientDelegate {
    func progressFor(id: UUID, context: [String: String]?, progress: Float, client: TUSClient) {
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
    
    // MARK: - Public Properties
    
    /// The number of uploads that the TUSClient will try to complete.
    public var remainingUploads: Int {
        uploads.count
    }
    public let sessionIdentifier: String
    public weak var delegate: TUSClientDelegate?
    
    // MARK: - Private Properties
    
    /// How often to try an upload if it fails. A retryCount of 2 means 3 total uploads max. (1 initial upload, and on repeated failure, 2 more retries.)
    private let retryCount = 9
    /// How long to delay the retry. This is intended to allow the server time to realize the connection has broken. Expected time in milliseconds.
    private let retryDelay = 500
    
    private let files: Files
    private var didStopAndCancel = false
    private let serverURL: URL
    private let scheduler = Scheduler()
    private let api: TUSAPI
    private let chunkSize: Int
    /// Keep track of uploads and their id's
    private var uploads = [UUID: UploadMetadata]()
    
#if os(iOS)
    @available(iOS 13.0, *)
    private lazy var backgroundClient: TUSBackground = {
        return TUSBackground(api: api, files: files, chunkSize: chunkSize)
    }()
#endif
    
    /// Initialize a TUSClient
    /// - Parameters:
    ///   - server: The URL of the server where you want to upload to.
    ///   - sessionIdentifier: An identifier to know which TUSClient calls delegate methods, also used for URLSession configurations.
    ///   - storageDirectory: A directory to store local files for uploading and continuing uploads. Leave nil to use the documents dir. Pass a relative path (e.g. "TUS" or "/TUS" or "/Uploads/TUS") for a relative directory inside the documents directory.
    ///   You can also pass an absolute path, e.g. "file://uploads/TUS"
    ///   - session: A URLSession you'd like to use. Will default to `URLSession.shared`.
    ///   - chunkSize: The amount of bytes the data to upload will be chunked by. Defaults to 512 kB.
    /// - Throws: File related errors when it can't make a directory at the designated path.
    public init(server: URL, sessionIdentifier: String, storageDirectory: URL? = nil, session: URLSession = URLSession.shared, chunkSize: Int = 500 * 1024) throws {
        self.sessionIdentifier = sessionIdentifier
        self.api = TUSAPI(session: session)
        self.files = try Files(storageDirectory: storageDirectory)
        self.serverURL = server
        self.chunkSize = chunkSize
        
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

    /// Start specific remaining uploads from locally stored files.
    @discardableResult
    public func start(taskIds: [UUID]) -> [(UUID, [String: String]?)] {
        didStopAndCancel = false
        let metaData = scheduleStoredTasks()
        return metaData.map { metaData in
            (metaData.id, metaData.context)
        }
    }

    /// Get which uploads aren't finished.
    public func getRemainingUploads() -> [(UUID, [String: String]?)] {
        let metaData = getStoredTasks()
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
    
    public func cancel(id: UUID) throws {
        let tasksToCancel = scheduler.allTasks.filter { ($0 as? IdentifiableTask)?.id == id }
        scheduler.cancelTasks(tasksToCancel)
    }
    
    /// This will cancel all running uploads and clear the local cache.
    /// Expect errors passed to the delegate for canceled tasks.
    /// - Warning: This method is destructive and will remove any stored cache.
    /// - Throws: File related errors
    public func reset() throws {
        stopAndCancelAll()
        try clearAllCache()
        uploads = [:]
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
    public func uploadFileAt(filePath: URL, uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil, startNow: Bool = true) throws -> UUID {
        didStopAndCancel = false
        do {
            let id = UUID()
            let destinationFilePath = try files.copy(from: filePath, id: id)
            try scheduleTask(for: destinationFilePath, id: id, uploadURL: uploadURL, customHeaders: customHeaders, context: context, startTask: startNow)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch let error {
            throw TUSClientError.couldNotCopyFile(underlyingError: error)
        }
    }
    
    /// Upload data
    /// - Parameters:
    ///   - data: The data to be upload
    ///   - preferredFileExtension: A file extension to add when saving the file. E.g. You can add ".JPG" to raw data that's being saved. This will help the uploader's metadata.
    ///   - uploadURL: A custom URL to upload to. For if you don't want to use the default server url. Will call the `create` on this custom url to get the definitive upload url.
    ///   - customHeaders: The headers to upload.
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: An id
    /// - Throws: TUSClientError
    @discardableResult
    public func upload(data: Data, preferredFileExtension: String? = nil, uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> UUID {
        didStopAndCancel = false
        do {
            let id = UUID()
            let filePath = try files.store(data: data, id: id, preferredFileExtension: preferredFileExtension)
            try scheduleTask(for: filePath, id: id, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
            return id
        } catch let error as TUSClientError {
            throw error
        } catch let error {
            throw TUSClientError.couldNotStoreFile(underlyingError: error)
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
    ///   - preferredFileExtension: A file extension to add when saving the file. E.g. You can add ".JPG" to raw data that's being saved. This will help the uploader's metadata.
    ///   - uploadURL: The URL to upload to. Leave nil for the default URL.
    ///   - customHeaders: Any headers you want to add to the upload
    ///   - context: Add a custom context when uploading files that you will receive back in a later stage. Useful for custom metadata you want to associate with the upload. Don't put sensitive information in here! Since a context will be stored to the disk.
    /// - Returns: An array of ids
    /// - Throws: TUSClientError
    @discardableResult
    public func uploadMultiple(dataFiles: [Data], preferredFileExtension: String? = nil, uploadURL: URL? = nil, customHeaders: [String: String] = [:], context: [String: String]? = nil) throws -> [UUID] {
        try dataFiles.map { data in
            try upload(data: data, preferredFileExtension: preferredFileExtension, uploadURL: uploadURL, customHeaders: customHeaders, context: context)
        }
    }
    
    // MARK: - Cache
    
    /// Throw away all files.
    /// - Important:This will clear the storage directory that you supplied.
    /// - Important:Don't call this while the client is active. Only between uploading sessions. You can check for the `remainingUploads` property.
    /// - Throws: TUSClientError if a file is found but couldn't be deleted. Or if files couldn't be loaded.
    public func clearAllCache() throws {
        do {
            try files.clearCacheInStorageDirectory()
        } catch let error {
            throw TUSClientError.couldNotDeleteFile(underlyingError: error)
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
        } catch let error {
            throw TUSClientError.couldNotDeleteFile(underlyingError: error)
        }
    }
   
    /// Retry a failed upload. Note that `TUSClient` already has an internal retry mechanic before it reports an upload as failure.
    /// If however, you like to retry an upload at a later stage, you can use this method to trigger the upload again.
    /// - Parameter id: The id of an upload. Received when starting an upload, or via the `TUSClientDelegate`.
    /// - Returns: True if the id is found. False if it's not found
    /// - Throws: `TUSClientError.couldNotRetryUpload` if it can't load an the file. Or file related errors.
    @discardableResult
    public func retry(id: UUID) throws -> Bool {
        do {
            guard uploads[id] == nil else { return false }
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
    public func failedUploadIDs() throws -> [UUID] {
        try files.loadAllMetadata().compactMap { metaData in
            if metaData.errorCount > retryCount {
                return metaData.id
            } else {
                return nil
            }
        }
    }
    
    // MARK: - Private
    
    /// Check for any uploads that are finished and remove them from the cache.
    private func removeFinishedUploads() {
        do {
            let metaDataList = try files.loadAllMetadata()
                .filter { metaData in
                    metaData.size == metaData.uploadedRange?.count
                }
            
            for metaData in metaDataList {
                try files.removeFileAndMetadata(metaData)
            }
        } catch let error {
            let tusError = TUSClientError.couldnotRemoveFinishedUploads(underlyingError: error)
            delegate?.fileError(error: tusError , client: self)
        }
    }
    
    /// Upload a file at the URL. Will not copy the path.
    /// - Parameter storedFilePath: The path where the file is stored for processing.
    private func scheduleTask(for storedFilePath: URL, id: UUID, uploadURL: URL?, customHeaders: [String: String], context: [String: String]?, startTask: Bool = true) throws {
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
            let url = uploadURL ?? serverURL
            return UploadMetadata(id: id, filePath: filePath, uploadURL: url, size: size, customHeaders: customHeaders, mimeType: filePath.mimeType.nonEmpty, context: context)
        }
        
        let metaData = try makeMetadata()
        
        func trackUpload() {
            uploads[id] = metaData
        }
        
        guard let task = try taskFor(metaData: metaData, api: api, files: files, chunkSize: chunkSize, progressDelegate: self) else {
            assertionFailure("Could not find a task for metaData \(metaData)")
            return
        }
        
        try store(metaData: metaData)
        trackUpload()
       
        delegate?.didInitializeUpload(id: id, context: context, client: self);
       
        if (startTask) {
          scheduler.addTask(task: task)
        }
    }
    
    /// Store UploadMetadata to disk
    /// - Parameter metaData: The `UploadMetadata` to store.
    /// - Throws: TUSClientError.couldNotStoreFileMetadata
    private func store(metaData: UploadMetadata) throws {
        do {
            // We store metadata here, so it's saved even if this job doesn't run this session. (Only created, doesn't mean it will run)
            try files.encodeAndStore(metaData: metaData)
        } catch let error {
            throw TUSClientError.couldNotStoreFileMetadata(underlyingError: error)
        }
    }
  
    /// Check which uploads aren't finished and return them.
    private func getStoredTasks() -> [UploadMetadata] {
        do {
            try files.makeDirectoryIfNeeded()
            let metaDataItems = try files.loadAllMetadata().filter({ metaData in
                // Only allow uploads where errors are below an amount
                metaData.errorCount <= retryCount && !metaData.isFinished
            })
            
            return metaDataItems
        } catch (let error) {
            let tusError = TUSClientError.couldNotLoadData(underlyingError: error)
            delegate?.fileError(error: tusError, client: self)
            return []
        }
    }

    /// Convert UUIDs into tasks.
    private func scheduleStoredTasks(taskIds: [UUID]) -> [UploadMetadata] {
        do {
            let metaDataItems = try files.loadAllMetadata().filter({ metaData in 
                // Only allow specified uploads and errors are below an amount
                metaData.errorCount <= retryCount && !metaData.isFinished && taskIds.contains( metaData.id )
            })
           
            for metaData in metaDataItems {
                try scheduleTask(for: metaData)
            }

            return metaDataItems
        } catch (let error) {
            let tusError = TUSClientError.couldNotLoadData(underlyingError: error)
            delegate?.fileError(error: tusError, client: self)
            return []
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
        } catch (let error) {
            let tusError = TUSClientError.couldNotLoadData(underlyingError: error)
            delegate?.fileError(error: tusError, client: self)
            return []
        }
    }
    
    /// Schedule a single task if needed. Will decide what task to schedule for the metaData.
    /// - Parameter metaData:The metaData the schedule.
    private func scheduleTask(for metaData: UploadMetadata) throws {
        guard let task = try taskFor(metaData: metaData, api: api, files: files, chunkSize: chunkSize, progressDelegate: self) else {
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
        } catch let error {
            let tusError = TUSClientError.couldNotDeleteFile(underlyingError: error)
            delegate?.fileError(error: tusError, client: self)
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
        func getMetaData() -> UploadMetadata? {
            switch task {
            case let task as CreationTask:
                return task.metaData
            case let task as UploadDataTask:
                return task.metaData
            case let task as StatusTask:
                return task.metaData
            default:
                return nil
            }
        }
        
        if didStopAndCancel {
            return
        }
        
        guard let metaData = getMetaData() else {
            assertionFailure("Could not fetch metadata from task \(task)")
            return
        }
        
        metaData.errorCount += 1
        do {
            try files.encodeAndStore(metaData: metaData)
        } catch let error {
            let tusError = TUSClientError.couldNotStoreFileMetadata(underlyingError: error)
            delegate?.fileError(error: tusError, client: self)
        }
        
        let canRetry = metaData.errorCount <= retryCount
        if canRetry {
            scheduler.addTask(task: task, delayMilliSeconds: retryDelay)
        } else { // Exhausted all retries, reporting back as failure.
            uploads[metaData.id] = nil
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
func taskFor(metaData: UploadMetadata, api: TUSAPI, files: Files, chunkSize: Int, progressDelegate: ProgressDelegate? = nil) throws -> ScheduledTask? {
    guard !metaData.isFinished else {
        return nil
    }
    
    if let remoteDestination = metaData.remoteDestination {
        let statusTask = StatusTask(api: api, remoteDestination: remoteDestination, metaData: metaData, files: files, chunkSize: chunkSize)
        statusTask.progressDelegate = progressDelegate
        return statusTask
    } else {
        let creationTask = try CreationTask(metaData: metaData, api: api, files: files, chunkSize: chunkSize)
        creationTask.progressDelegate = progressDelegate
        return creationTask
    }
}

extension TUSClient: ProgressDelegate {
    
    @available(iOS 11.0, macOS 10.13, *)
    func progressUpdatedFor(metaData: UploadMetadata, totalUploadedBytes: Int) {
        delegate?.progressFor(id: metaData.id, context: metaData.context, bytesUploaded: totalUploadedBytes, totalBytes: metaData.size, client: self)

        /* var totalBytesUploaded: Int = 0 */
        /* var totalSize: Int = 0 */
        /* for (_, metaData) in uploads { */
        /*     totalBytesUploaded += metaData.uploadedRange?.count ?? 0 */
        /*     totalSize += metaData.size */
        /* } */

        /* delegate?.totalProgress(bytesUploaded: totalBytesUploaded, totalBytes: totalSize, client: self) */
    }
}

private extension URL {
    var mimeType: String {
        let pathExtension = self.pathExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}

