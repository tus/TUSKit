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

// TODO: Doc comments TUSClient

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
    
    private var total = 0
    
    public init(config: TUSConfig, fileManager: FileManager = FileManager.default) {
        self.config = config
        scheduler.delegate = self
    }
    
    // MARK: - Upload single file
    
    /// Upload data located at a url.  This file will be copied to a TUS directory for processing..
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameter filePath: The path to a file on a local filesystem.
    /// - Throws: TUSClientError
    public func uploadFileAt(filePath: URL) throws {
        
        do {
            let destinationFilePath = try Files.copy(from: filePath)
            createTaskFor(storedFilePath: destinationFilePath)
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
            createTaskFor(storedFilePath: filePath)
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
    private func createTaskFor(storedFilePath: URL) {
        // TODO: Get size based on network speed
        let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
        let task = CreationTask(filePath: storedFilePath, network: Network(), chunkSize: sizeInKiloBytes)
        scheduler.addTask(Task: task)
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

/// `CreationTask` Prepares the server for a file upload.
/// The server will return a path to upload to.
final class CreationTask: Task {
    let filePath: URL
    let network: Network
    let chunkSize: Int

    init(filePath: URL, network: Network, chunkSize: Int) {
        self.filePath = filePath
        self.network = network
        self.chunkSize = chunkSize
    }
    
    func run(completed: @escaping TaskCompletion) {
        // TODO: Write metadata to file
        network.create { [unowned self] remoteDestination in
            // TODO: Error handling
            let size = try! filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Data(contentsOf: filePath).count
            let ranges = (0..<size).chunkRanges(size: chunkSize)
            
            let tasks = ranges.map { range in
                UploadDataTask(remoteDestination: remoteDestination, filePath: filePath, range: range, network: Network())
            }
            
            completed(tasks)
        }
    }
}

/// The upload task will upload to a destination.
final class UploadDataTask: Task {
    
    let remoteDestination: URL
    let filePath: URL
    let range: Range<Int>
    let network: Network
    
    init(remoteDestination: URL, filePath: URL, range: Range<Int>, network: Network) {
        self.remoteDestination = remoteDestination
        self.filePath = filePath
        self.range = range
        self.network = network
    }
    
    func run(completed: @escaping ([Task]) -> ()) {
        // TODO: Error handling
        let data = try! Data(contentsOf: filePath)
        let sub = data[range]
        
        network.upload(data: sub, range: range) {
            completed([])
        }
    }
    
    func cleanUp() {
        // Delete file
    }
}
