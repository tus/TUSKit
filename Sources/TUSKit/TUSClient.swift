//
//  TUSClient.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

/// The errors that are passed from TUSClient
public struct TUSClientError: Error {
    let code: Int

    // Maintenance: We use static lets on a struct, instead of an enum, so that adding new cases won't break stability.
    // Alternatively we can ask users to always use `unknown default`, but we can't guarantee that everyone will use that.
    public static let couldNotCopyFile = TUSClientError(code: 1)
    public static let couldNotStoreFile = TUSClientError(code: 2)
    public static let filesizeNotKnown = TUSClientError(code: 3)
}

/// The TUSKit client.
///
/// Use this type to initiate uploads.
///
/// ## Example
///
///     let client = TUSClient(config: TUSConfig(server: liveDemoPath))
///
public final class TUSClient {
    
    private let config: TUSConfig
    private let scheduler = Scheduler()
    private let storageDirectory: URL?
    
    private var total = 0
    
    public init(config: TUSConfig, storageDirectory: URL?) {
        self.config = config
        self.storageDirectory = storageDirectory
        
        scheduler.delegate = self
        
        do {
            let tasks = try loadTasksFromPersistentStore()
            scheduler.addTasks(tasks: tasks)
        } catch {
            // TODO: Return error, can't load from store
        }
    }
    
    private func loadTasksFromPersistentStore() throws -> [Task] {
        // Improvement: Doesn't group a single upload into multiple.
        // Once concurrent uploading comes into play. Return [[Task]] so
        
        // Get the document directory url
        let metaData = try Files.loadAllMetadata()
        
        // TODO: Reuse TUSAPI from other methods
        let api = TUSAPI(uploadURL: config.server, network: URLSession.shared)
        return metaData.map { metaData in
            // TODO: Check expiration date?
            
            if let remoteDestination = metaData.remoteDestination {
                print("Creating status task")
                // TODO: Only create status task if we don't support concurrency
                // TODO: What about status if chunks have been randomly uploaded? Status only gives one number.
                return StatusTask(api: api, remoteDestination: remoteDestination, metaData: metaData)
            } else {
                // TODO: Reuse chunksize logic
                print("Create creation task")
                return CreationTask(filePath: metaData.filePath, api: api)
            }
             
        }
    }
    
    // MARK: - Upload single file
    
    /// Upload data located at a url.  This file will be copied to a TUS directory for processing..
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameter filePath: The path to a file on a local filesystem.
    /// - Throws: TUSClientError
    public func uploadFileAt(filePath: URL) throws {
        do {
            let destinationFilePath = try Files.copy(from: filePath)
            scheduleCreationTask(for: destinationFilePath)
        } catch {
            throw TUSClientError.couldNotCopyFile
        }
    }
    
    /// Upload data
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    public func upload(data: Data) throws {
        do {
            let filePath = try Files.store(data: data)
            scheduleCreationTask(for: filePath)
        } catch {
            throw TUSClientError.couldNotStoreFile
        }
        
    }
    
    // MARK: - Upload multiple files
    
    /// Upload multiple files by giving their url
    /// - Parameter filePaths: An array of filepaths, represented by URLs
    public func uploadFiles(filePaths: [URL]) throws {
        try filePaths.forEach(uploadFileAt)
    }
    
    /// Upload multiple data files
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    public func uploadMultiple(dataFiles: [Data]) throws {
        for data in dataFiles {
            try upload(data: data)
        }
    }
    
    // MARK: - Private
    
    /// Upload a file at the URL. Will not copy the path.
    /// - Parameter storedFilePath: The path where the file is stored for processing.
    private func scheduleCreationTask(for storedFilePath: URL) {
        let task = CreationTask(filePath: storedFilePath, api: TUSAPI(uploadURL: config.server, network: URLSession.shared))
        scheduler.addTask(task: task)
    }

}

extension TUSClient: SchedulerDelegate {
    func didFinishTask(task: Task, scheduler: Scheduler) {
//        let progress = 100 - (Float(scheduler.nrOfPendingTasks) / Float(total) * 100)
        
        // TODO: Use logger
        print("Finished task \(task)")
    }
    
    func didStartTask(task: Task, scheduler: Scheduler) {
        // TODO: Use logger
        print("Did start \(task)")
    }
}

final class StatusTask: Task {
    
    let api: TUSAPI
    let remoteDestination: URL
    let metaData: UploadMetadata
    
    init(api: TUSAPI, remoteDestination: URL, metaData: UploadMetadata) {
        self.api = api
        self.remoteDestination = remoteDestination
        self.metaData = metaData
    }
    
    func run(completed: @escaping TaskCompletion) {
        // TODO: Logger
        print("Statustask running for \(metaData.filePath)")
        // TODO: On failure, try uploading from the start. Create creationtask.
        api.status(remoteDestination: remoteDestination) { [unowned self] length, offset in
            if length != metaData.size {
                // TODO: Server has different size, handle this out of sync situation.
                // TODO: Document this situation too?
            }
            
            if offset > metaData.size {
                // TODO: Recover
            }
            
            metaData.uploadedRange = 0..<offset
            
            if offset == metaData.size {
                print("Already done")
                // TODO: Force
                try! Files.removeFileAndMetadata(metaData)
                completed([])
            } else {
                let task = try! UploadDataTask(api: api, metaData: metaData, range: offset..<metaData.size)
                completed([task])
            }
            
            
        }
    }
}

/// `CreationTask` Prepares the server for a file upload.
/// The server will return a path to upload to.
final class CreationTask: Task {
    let filePath: URL
    let api: TUSAPI
    let chunkSize: Int?
    var metaData: UploadMetadata

    init(filePath: URL, api: TUSAPI, chunkSize: Int? = nil) {
        self.filePath = filePath
        self.api = api
        self.chunkSize = chunkSize
        
        // TODO: Resolve force unwrap
        let size = try! filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Data(contentsOf: filePath).count
        var mimeType: String?
        
        let retrievedMimeType = filePath.mimeType
        if !retrievedMimeType.isEmpty {
            mimeType = retrievedMimeType
        }
        
        self.metaData = UploadMetadata(filePath: filePath, size: size, mimeType: mimeType)
        // TODO: Remove force unwrap
        try! Files.encodeAndStore(metaData: metaData)
        // We already store metadata, cause if this isn't run. The file is stored by now.
    }
    
    func run(completed: @escaping TaskCompletion) {
        // TODO: Write metadata to file
        // TODO: Force
        let size = metaData.size
        guard size > 0 else {
            
            // Make sure even sync code comes next runloop, so behavior stays consistent
            DispatchQueue.main.async {
                // TODO: Error. Nothing to upload. Empty file.
                completed([])
            }
            return
        }
        
        api.create(metaData: metaData) { [unowned self] remoteDestination in
            // TODO: Error handling
            // TODO: Only if concurrency is supported.
//            let ranges = (0..<size).chunkRanges(size: chunkSize)
//
//            let tasks = ranges.map { range in
//                UploadDataTask(remoteDestination: remoteDestination, filePath: filePath, range: range, api: api)
//            }
//
            // TODO: Only if persistence is allowed
            metaData.remoteDestination = remoteDestination
            // TODO: Force unwrap
            try! Files.encodeAndStore(metaData: metaData)
            
            // TODO: Use logger
            print("Received \(remoteDestination)")
            print("Going to upload \(size) bytes")
            // File is created remotely. Now start first datatask.
            // TODO: Force try
            let task: UploadDataTask
            if let chunkSize = chunkSize {
                task = try! UploadDataTask(api: api, metaData: metaData, range: 0..<chunkSize)
            } else {
                task = try! UploadDataTask(api: api, metaData: metaData)
            }
            
            // TODO: Update metadata
            completed([task])
        }
    }
}

/// The upload task will upload to a destination.
final class UploadDataTask: Task {
    
    let api: TUSAPI
    let metaData: UploadMetadata
    let remoteDestination: URL
    let range: Range<Int>?
    
    /// Specify range, or upload
    /// - Parameters:
    ///   - api: The TUSAPI
    ///   - metaData: The metadata of the file to upload
    ///   - range: Specify range to upload. If omitted, will upload entire file at once.
    /// - Throws: File and network related errors
    init(api: TUSAPI, metaData: UploadMetadata, range: Range<Int>? = nil) throws {
        self.api = api
        self.metaData = metaData
        
        if let range = range, range.count == 0 {
            // Finished here somehow
            assertionFailure("Ended up with an empty range to upload.")
            // TODO: Delete file
        }
        
        if (range?.count ?? 0) > metaData.size {
            // TODO: Make error
            assertionFailure("The range to upload is larger than the size")
        }
        
        if let destination = metaData.remoteDestination {
            self.remoteDestination = destination
        } else {
            // TODO: Throw. Recover from error
            fatalError("No remote destination for upload task")
        }
        self.range = range
    }
    
    func run(completed: @escaping ([Task]) -> ()) {
        // TODO: Check if data is already uploaded. Maybe deletion got interrupted.
        print("RUnning upload datatask \(range)")

        // TODO: Error handling
        guard let data = try? Data(contentsOf: metaData.filePath) else {
            // TODO: Error handling. Suggest to delete metadata?
            DispatchQueue.main.async {
                completed([])
            }
            return
        }
        
    
        
        let dataToUpload: Data
        if let range = range {
            
            dataToUpload = data[range]
            
        } else {
            dataToUpload = data
        }
        print("Going to upload \(String(describing: range))")
        
        // TODO: If concurrency is not supported (or some flag is passed), create a new task after this one to determine what's left. Maybe add count to this task to help determin.
        api.upload(data: dataToUpload, range: range, location: remoteDestination) { [unowned self] offset in
            print("Uploaded \(offset)")
            metaData.uploadedRange = 0..<offset
//            // TODO: Force
            try! Files.encodeAndStore(metaData: metaData)

            // Decide if more datatasks are needed, create those too if needed.
            print("offset \(offset) size \(metaData.size)")
            if offset == metaData.size {
                // Finished uploading.
                try! Files.removeFileAndMetadata(metaData)
                print("Upload finished, url is \(remoteDestination)")
                completed([])
                return
            }
            
            let task: UploadDataTask
            if let range = range {
                print("Not finished uploading, will now upload \(range)")
                let chunkSize = range.count
                let nextRange = offset..<min((offset + chunkSize), metaData.size)
                    // TODO: Force try
                task = try! UploadDataTask(api: api, metaData: metaData, range: nextRange)
            } else {
                task = try! UploadDataTask(api: api, metaData: metaData)
                
            }
            
            completed([task])
            
        }
    }
}
