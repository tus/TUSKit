//
//  UploadDataTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// The upload task will upload to data a destination.
/// Will spawn more UploadDataTasks if an upload isn't complete.
final class UploadDataTask: NSObject, IdentifiableTask {
    
    // MARK: - IdentifiableTask
    
    var id: UUID {
        metaData.id
    }
    
    weak var progressDelegate: ProgressDelegate?
    let metaData: UploadMetadata
    
    let queue = DispatchQueue(label: "com.tuskit.uploadDataTask")
    
    private var isCanceled = false
    
    private let api: TUSAPI
    private let files: Files
    private let range: Range<Int>?
    private var observation: NSKeyValueObservation?
    private weak var sessionTask: URLSessionUploadTask?
    
    /// Specify range, or upload
    /// - Parameters:
    ///   - api: The TUSAPI
    ///   - metaData: The metadata of the file to upload
    ///   - range: Specify range to upload. If omitted, will upload entire file at once.
    /// - Throws: File and network related errors
    init(api: TUSAPI, metaData: UploadMetadata, files: Files, range: Range<Int>? = nil) throws {
        self.api = api
        self.metaData = metaData
        self.files = files
        
        if let range = range, range.count == 0 {
            // Improve: Enrich error
            assertionFailure("Ended up with an empty range to upload.")
            throw TUSClientError.couldNotUploadFile(underlyingError: TUSClientError.emptyUploadRange)
        }
        
        if (range?.count ?? 0) > metaData.size {
            assertionFailure("The range \(String(describing: range?.count)) to upload is larger than the size \(metaData.size)")
            throw TUSClientError.couldNotUploadFile(underlyingError: TUSClientError.rangeLargerThanFile)
        }
        
        if let destination = metaData.remoteDestination {
            self.metaData.remoteDestination = destination
        } else {
            assertionFailure("No remote destination for upload task")
            throw TUSClientError.couldNotUploadFile(underlyingError: TUSClientError.missingRemoteDestination)
        }
        self.range = range
    }
    
    func run() async throws -> [any ScheduledTask] {
        guard !metaData.isFinished else {
            throw TUSClientError.uploadIsAlreadyFinished
        }
        
        guard let remoteDestination = metaData.remoteDestination else {
            throw TUSClientError.missingRemoteDestination
        }
        
        let dataToUpload: Data
        let file: URL
        do {
            dataToUpload = try loadData()
            file = try prepareUploadFile()
        } catch let error {
            let tusError = TUSClientError.couldNotLoadData(underlyingError: error)
            throw tusError
        }
        
        if isCanceled {
            return []
        }
        
        let progress = try await api.upload(fromFile: file, offset: range?.lowerBound ?? 0 , location: remoteDestination, metaData: metaData)
        observation?.invalidate()
#warning("This is what we used to do; needs some larger refactoring once everything Sendable to make it work again.")
        return try taskCompleted(receivedOffset: progress)
        // self?.taskCompleted(result: result, completed: completed)
        
        /*
        sessionTask = task
        
        if #available(iOS 11.0, macOS 10.13, *) {
            observeTask(task: task, size: dataToUpload.count)
        }
         */
    }
    
    func taskCompleted(receivedOffset: Int) throws -> [any ScheduledTask] {
            do {
                let currentOffset = metaData.uploadedRange?.upperBound ?? 0
                metaData.uploadedRange = 0..<receivedOffset
                
                let hasFinishedUploading = receivedOffset == metaData.size
                if hasFinishedUploading {
                    try files.encodeAndStore(metaData: metaData)
                    return []
                } else if receivedOffset == currentOffset {
                    //                improvement: log this instead
                    //                    assertionFailure("Server returned a new uploaded offset \(offset), but it's lower than what's already uploaded \(metaData.uploadedRange!), according to the metaData. Either the metaData is wrong, or the server is returning a wrong value offset.")
                    throw TUSClientError.receivedUnexpectedOffset
                }
                
                try files.encodeAndStore(metaData: metaData)
                
                // If the task has been canceled
                // we don't continue to create subsequent UploadDataTasks
                if self.isCanceled {
                    return []
                }
                
                let nextRange: Range<Int>?
                if let range = range {
                    let chunkSize = range.count
                    nextRange = receivedOffset..<min((receivedOffset + chunkSize), metaData.size)
                } else {
                    nextRange = nil
                }
                
                let task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange)
                task.progressDelegate = progressDelegate
                return [task]
            } catch let error as TUSClientError {
                throw error
            } catch {
                throw TUSClientError.couldNotUploadFile(underlyingError: error)
            }
    }
    
    @available(iOS 11.0, macOS 10.13, *)
    func observeTask(task: URLSessionUploadTask, size: Int) {
        let targetRange = 0..<size
        let uploaded = metaData.uploadedRange?.count ?? 0
        
        observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            self?.queue.async {
                guard let self = self else { return }
                guard progress.fractionCompleted <= 1 else { return }
                let bytes = progress.fractionCompleted * Double(targetRange.count)
                
                let totalUploaded = uploaded + Int(bytes)
                self.progressDelegate?.progressUpdatedFor(metaData: self.metaData, totalUploadedBytes: totalUploaded)
            }
        }
    }
    
    func prepareUploadFile() throws -> URL {
        let fileHandle = try FileHandle(forReadingFrom: metaData.filePath)
        
        defer {
            fileHandle.closeFile()
        }
        
        // Can't use switch with #available :'(
        let data: Data
        if let range = self.range, #available(iOS 13.0, macOS 10.15, *) { // Has range, for newer versions
            try fileHandle.seek(toOffset: UInt64(range.startIndex))
            data = fileHandle.readData(ofLength: range.count)
        } else if let range = self.range { // Has range, for older versions
            fileHandle.seek(toFileOffset: UInt64(range.startIndex))
            data = fileHandle.readData(ofLength: range.count)
            /*
             } else if #available(iOS 13.4, macOS 10.15, *) { // No range, newer versions.
             Note that compiler and api says that readToEnd is available on macOS 10.15.4 and higher, but yet github actions of 10.15.7 fails to find the member.
             return try fileHandle.readToEnd()
             */
        } else { // No range, older versions
            data = fileHandle.readDataToEndOfFile()
        }
        
        return try files.store(data: data, id: metaData.id, preferredFileExtension: "uploadData")
    }
    
    /// Load data based on range (if there). Uses FileHandle to be able to handle large files
    /// - Returns: The data, or nil if it can't be loaded.
    func loadData() throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: metaData.filePath)
        
        defer {
            fileHandle.closeFile()
        }
        
        // Can't use switch with #available :'(
        
        if let range = self.range, #available(iOS 13.0, macOS 10.15, *) { // Has range, for newer versions
            try fileHandle.seek(toOffset: UInt64(range.startIndex))
            return fileHandle.readData(ofLength: range.count)
        } else if let range = self.range { // Has range, for older versions
            fileHandle.seek(toFileOffset: UInt64(range.startIndex))
            return fileHandle.readData(ofLength: range.count)
            /*
             } else if #available(iOS 13.4, macOS 10.15, *) { // No range, newer versions.
             Note that compiler and api says that readToEnd is available on macOS 10.15.4 and higher, but yet github actions of 10.15.7 fails to find the member.
             return try fileHandle.readToEnd()
             */
        } else { // No range, older versions
            return fileHandle.readDataToEndOfFile()
        }
    }
    
    func cancel() {
        isCanceled = true
        observation?.invalidate()
        sessionTask?.cancel()
    }
    
    deinit {
        observation?.invalidate()
    }
}
