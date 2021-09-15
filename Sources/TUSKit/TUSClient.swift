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
    public static let filesizeNotKnown = TUSClientError(code: 2)
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
    
    private var total = 0
    
    public init(config: TUSConfig, fileManager: FileManager = FileManager.default) {
        self.config = config
        scheduler.delegate = self
    }
    
    /// Upload data located at a url.
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameter filePath: The path to a file on a local filesystem.
    /// - Throws: TUSClientError
    public func uploadFileAt(filePath: URL) throws {
        do {
            let destinationFilePath = try Files.copy(from: filePath)
            let size = try destinationFilePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Data(contentsOf: destinationFilePath).count
            
            // TODO: Duplicate size
            let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
            let ranges = (0..<size).chunkRanges(size: sizeInKiloBytes)
            
            scheduleUploadsFor(filePath: destinationFilePath, ranges: ranges)
        } catch {
            throw TUSClientError.couldNotCopyFile
        }
    }
    
    /// Upload data
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    public func upload(data: Data) throws {
        scheduleUploadsFor(data: data)
    }
    
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
            scheduleUploadsFor(data: data)
        }
    }
    
    /// Turns a piece of Data into chunked UploadImage tasks
    /// - Parameter data: Image Data, which will be chunked to upload
    private func scheduleUploadsFor(data: Data) {
        // TODO: error handling
        
        // Store file now
        // TODO: Force
        let filePath = try! Files.store(data: data)
        let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
        let ranges = data.chunkRanges(size: sizeInKiloBytes)
        scheduleUploadsFor(filePath: filePath, ranges: ranges)
    }
    
    /// Start upload based on a file path
    /// - Parameters:
    ///   - filePath: The url to a file's location
    ///   - ranges: The ranges of the file to upload
    private func scheduleUploadsFor(filePath: URL, ranges: [Range<Int>]) {
        let tasks = ranges.map { range in
            UploadDataTask(filePath: filePath, range: range, uploader: Uploader())
        }
        
        total += tasks.count
        scheduler.addGroupedTasks(tasks: tasks)
    }

}

extension TUSClient: SchedulerDelegate {
    func didFinishTask(task: Task, scheduler: Scheduler) {
        let progress = 100 - (Float(scheduler.nrOfPendingTasks) / Float(total) * 100)
        // TODO: Use logger
        print("total \(total) running \(scheduler.nrOfRunningTasks) pending \(scheduler.nrOfPendingTasks) PROGRESS \(progress)")
        
        if progress == 100 {
            total = 0
        }
    }
    
    func didStartTask(task: Task, scheduler: Scheduler) {
        // TODO: Use logger
        print("Did start \(task)")
    }
}

final class UploadDataTask: Task {
    
    let filePath: URL
    let range: Range<Int>
    let uploader: Uploader
    
    init(filePath: URL, range: Range<Int>, uploader: Uploader) {
        self.filePath = filePath
        self.range = range
        self.uploader = uploader
    }
    
    func run(completed: @escaping ([Task]) -> ()) {
        // TODO: Error handling
        let data = try! Data(contentsOf: filePath)
        let sub = data[range]
        
        uploader.upload(data: sub, range: range) {
            completed([])
        }
    }
    
    func cleanUp() {
        // Delete file
    }
}
