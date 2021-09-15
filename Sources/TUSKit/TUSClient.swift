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
    public static let fileNotFound = TUSClientError(code: 1)
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
            let url = try Files.copy(from: filePath)
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                print("Size is unknown")
                // TODO: Load data and try getting size
                throw TUSClientError.fileNotFound
            }
            
            // TODO: Duplicate
            let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
            let ranges = (0..<size).chunkRanges(size: sizeInKiloBytes)
            
            scheduleUploadsFor(url: url, ranges: ranges)
        } catch {
            throw TUSClientError.fileNotFound
        }
//        // TODO: Copy file from URL
//        let data = try findData(for: filePath)
//        scheduleUploadsFor(data: data)
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
        let url = try! Files.store(data: data)
        let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
        let ranges = data.chunkRanges(size: sizeInKiloBytes)
        scheduleUploadsFor(url: url, ranges: ranges)
    }
    
    private func scheduleUploadsFor(url: URL, ranges: [Range<Int>]) {
        let tasks = ranges.map { range in
            UploadDataTask(url: url, range: range, uploader: Uploader())
        }
        
        total += tasks.count
        scheduler.addGroupedTasks(tasks: tasks)
    }

    /// Get Data based on URL
    /// - Parameter url: The target url to load data from
    /// - Throws: Throws TUSClientError
    /// - Returns: The loaded Data
    private func findData(for url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            let prefixedPath = "file://" + url.absoluteString
            let url = try URL(string:prefixedPath).or(willThrow: TUSClientError.fileNotFound)
            let data = try? Data(contentsOf: url)
            return try data.or(willThrow: TUSClientError.fileNotFound)
        }
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
    
//    let chunk: Data
    let url: URL
    let range: Range<Int>
    let uploader: Uploader
    
    init(url: URL, range: Range<Int>, uploader: Uploader) {
        self.url = url
        self.range = range
        self.uploader = uploader
    }
    
    func run(completed: @escaping ([Task]) -> ()) {
        // TODO: Error handling
        let data = try! Data(contentsOf: url)
        let sub = data[range]
        
        uploader.upload(data: sub, range: range) {
            completed([])
        }
    }
    
    func cleanUp() {
        // Delete file
    }
}
