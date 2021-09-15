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
        guard FileManager.default.fileExists(atPath: filePath.absoluteString) else {
            throw TUSClientError.fileNotFound
        }
        
        // Improvement: Loading data can also happen later, when the task actually runs. Maybe nest this group in another task that will load and chunk the data.
        let data = try findData(for: filePath)
        scheduleUploadsFor(data: data)
    }
    
    /// Upload data
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    public func upload(data: Data) throws {
        scheduleUploadsFor(data: data)
    }
    
    /// Upload data
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
        func makeUploadDataTask(data: Data) -> [UploadDataTask] {
            let uploader = Uploader()
            // TODO: Chunk according to speed.
            let sizeInKiloBytes = 500 * 1024// Uses safe speed, 500kb
            let chunks = data.chunks(size: sizeInKiloBytes) // Originally 5mb:  5 * 1024 * 1024
            return chunks.map { chunk in
                return UploadDataTask(chunk: chunk, uploader: uploader)
            }
        }
        
        let groupedTasks = makeUploadDataTask(data: data)
        total += groupedTasks.count
        print("Creating \(groupedTasks.count) tasks for data")
        scheduler.addGroupedTasks(tasks: groupedTasks)
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
    
    let chunk: Data
    let uploader: Uploader
    
    init(chunk: Data, uploader: Uploader) {
        self.chunk = chunk
        self.uploader = uploader
    }
    
    func run(completed: @escaping ([Task]) -> ()) {
        
        uploader.upload(data: chunk, offset: 0) {
            print("Finished uploading task")
            completed([])
        }
    }
    
    func cleanUp() {
        // Delete file
    }
}
