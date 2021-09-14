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
    // Alternatively we can opt in for unknown default, but we can't guarantee that everyone will use that.
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
    
    public init(config: TUSConfig, fileManager: FileManager = FileManager.default) {
        self.config = config
    }
    
    /// Upload data located at a url.
    /// If data can not be found at a location, it will attempt to locate the data by prefixing the path with file://
    /// - Parameter filePath: The path to a file on a local filesystem.
    /// - Throws: TUSClientError
    public func uploadFileAt(filePath: URL) throws {
        guard FileManager.default.fileExists(atPath: filePath.absoluteString) else {
            throw TUSClientError.fileNotFound
        }
        
        let data = try findData(for: filePath)
        scheduleUploadsFor(data: data)
    }
    
    /// Upload data
    /// - Parameter data: The data to be uploaded.
    /// - Throws: TUSClientError
    public func upload(data: Data) throws {
        scheduleUploadsFor(data: data)
    }
    
    /// Turns a piece of Data into chunked UploadImage tasks
    /// - Parameter data: Image Data, which will be chunked to upload
    private func scheduleUploadsFor(data: Data) {
        func makeUploadImages(data: Data) -> [UploadImage] {
            let uploader = Uploader()
            let chunks = data.chunks(size: 5 * 1024 * 1024)
            return chunks.map { chunk in
                return UploadImage(chunk: chunk, uploader: uploader)
            }
        }
        
        let groupedTasks = makeUploadImages(data: data)
        scheduler.addGroupedTasks(workTask: groupedTasks)
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

final class UploadImage: WorkTask {
    
    let chunk: Data
    let uploader: Uploader
    
    init(chunk: Data, uploader: Uploader) {
        self.chunk = chunk
        self.uploader = uploader
    }
    
    func run(completed: @escaping ([WorkTask]) -> ()) {
        uploader.upload(data: chunk, offset: 0) {
            completed([])
        }
    }
    
    func cleanUp() {
        // Delete file
    }
}

/*
/// The purpose of an `UploadTask` is to get a file uploaded. No matter what happens under the hood
/// An `UploadTask` takes care of; Preparation (Chunking data), the uploading itself (indirectly, using an uploader), grouping the uploadresults back into one, and cleaning up afterwards.
public final class UploadTask {
    let group = DispatchGroup()
    
    enum Source {
        case filePath(URL)
        case data(Data)
    }
    
    let source: Source
    let uploader: Uploader
    
    init(source: Source, uploader: Uploader) {
        self.source = source
        self.uploader = uploader
    }
    
    func run() -> [UploadImage] {
        let data = getData()
        
        // Split data into multiple upload tasks
        let chunks = data.chunks(size: 5 * 1024 * 1024)
        return chunks.map { chunk in
            return UploadImage(chunk, uploader)
        }
    }
    
    func run(completed: @escaping () -> Void) {
        let data = getData()
        
        // Split data into multiple uploads
        let chunks = data.chunks(size: 5 * 1024 * 1024)
        
        // TODO: Store data
        
        // TODO: Continue or new. If new, create different url request
        
        // Upload chunks
        for chunk in chunks {
            group.enter()
            uploader.upload(data: chunk, offset: 0) { [unowned group] in
                group.leave()
            }
        }
        
        // Group results from chunked uploads back into one again.
        // TODO: Get results
        // TODO: Cancel if one fails? Or retry?
        group.notify(queue: DispatchQueue.global()) {
            completed()
        }
        
        // TODO: File cleanup
    }
    
    private func getData() -> Data {
        switch source {
        case .filePath(let url):
            return findData(for: url)
        case .data(let d):
            return d
        }
    }
    
    
}

*/
