//
//  UploadDataTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// The upload task will upload to data a destination.
/// Will spawn more UploadDataTasks if an upload isn't complete.
final class UploadDataTask: NSObject, Task {
    
    weak var progressDelegate: ProgressDelegate?
    let metaData: UploadMetadata
    
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
            throw TUSClientError.couldNotUploadFile
        }
        
        if (range?.count ?? 0) > metaData.size {
            assertionFailure("The range \(String(describing: range?.count)) to upload is larger than the size \(metaData.size)")
            throw TUSClientError.couldNotUploadFile
        }
        
        if let destination = metaData.remoteDestination {
            self.metaData.remoteDestination = destination
        } else {
            assertionFailure("No remote destination for upload task")
            throw TUSClientError.couldNotUploadFile
        }
        self.range = range
    }
    
    func run(completed: @escaping TaskCompletion) {
        guard !metaData.isFinished else {
            DispatchQueue.main.async {
                completed(.failure(TUSClientError.uploadIsAlreadyFinished))
            }
            return
        }
        
        guard let data = try? Data(contentsOf: metaData.filePath) else {
            DispatchQueue.main.async {
                completed(.failure(TUSClientError.couldNotLoadData))
            }
            return
        }
        
        guard let remoteDestination = metaData.remoteDestination,
              let dataToUpload = loadData() else {
                  assertionFailure("Somehow did not have a remote destination to upload to.")
                  completed(Result.failure(TUSClientError.couldNotUploadFile))
                  return
              }
        
        let task = api.upload(data: dataToUpload, range: range, location: remoteDestination) { [weak self] result in
            guard let self = self else { return }
            // Getting rid of needing .self inside this closure
            let metaData = self.metaData
            let files = self.files
            let range = self.range
            let api = self.api
            let progressDelegate = self.progressDelegate
            
            do {
                let offset = try result.get()
                let currentOffset = metaData.uploadedRange?.upperBound ?? 0
                
                let hasFinishedUploading = offset == metaData.size
                if hasFinishedUploading {
                    metaData.uploadedRange = 0..<offset
                    try files.encodeAndStore(metaData: metaData)
                    completed(.success([]))
                    return
                } else if offset == currentOffset {
//                    print("Server returned a new uploaded offset \(offset), but it's lower than what's already uploaded \(metaData.uploadedRange!), according to the metaData. Either the metaData is wrong, or the server is returning a wrong value offset.")
                    throw TUSClientError.receivedUnexpectedOffset
                }
                
                metaData.uploadedRange = 0..<offset
                try files.encodeAndStore(metaData: metaData)
                
                let task: UploadDataTask
                if let range = range {
                    let chunkSize = range.count
                    let nextRange = offset..<min((offset + chunkSize), metaData.size)
                    task = try UploadDataTask(api: api, metaData: metaData, files: files, range: nextRange)
                } else {
                    task = try UploadDataTask(api: api, metaData: metaData, files: files)
                }
                task.progressDelegate = progressDelegate
                completed(.success([task]))
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotUploadFile))
            }
            
        }
        
        sessionTask = task
        
        if #available(iOS 11.0, macOS 10.13, *) {
            observation = observeTask(task: task, size: data.count)
        }
    }
    
    @available(iOS 11.0, macOS 10.13, *)
    func observeTask(task: URLSessionUploadTask, size: Int) -> NSKeyValueObservation? {
        let targetRange = self.range ?? 0..<size
        return task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            guard let self = self else { return }
            guard progress.fractionCompleted <= 1 else { return }
            let index = self.metaData.uploadedRanges.firstIndex { $0.first == targetRange.lowerBound }
            let uploadedOffset: Double = progress.fractionCompleted * Double(targetRange.count)
            let newlyUploadedRange = targetRange.lowerBound..<Int(uploadedOffset) + targetRange.lowerBound
            guard newlyUploadedRange.count > 0 else { return }
            
            if let currentIndex = index {
                // Update index of existing range
                self.metaData.uploadedRanges[currentIndex] = newlyUploadedRange
            } else {
                // Range not part of metadata yet, add it.
                self.metaData.uploadedRanges.append(newlyUploadedRange)
            }
            self.progressDelegate?.progressUpdatedFor(metaData: self.metaData)
        }
    }
    
    /// Load data based on range (if there). Uses FileHandle to be able to handle large files
    /// - Returns: The data, or nil if it can't be loaded.
    func loadData() -> Data? {
        guard let fileHandle = try? FileHandle(forReadingFrom: metaData.filePath) else {
            assertionFailure("Could not load file \(metaData.filePath)")
            return nil
        }
        
        defer {
            fileHandle.closeFile()
        }
        
        do {
            // Can't use switch with #available :'(
            
            if let range = self.range, #available(iOS 13.0, macOS 10.15, *) { // Has range, for newer versions
                try fileHandle.seek(toOffset: UInt64(range.startIndex))
                return fileHandle.readData(ofLength: range.count)
            } else if let range = self.range { // Has range, for older versions
                fileHandle.seek(toFileOffset: UInt64(range.startIndex))
                return fileHandle.readData(ofLength: range.count)
            } else if #available(iOS 13.4, macOS 10.15.4, *) { // No range, newer versions
                return try fileHandle.readToEnd()
            } else { // No range, older versions
                return fileHandle.readDataToEndOfFile()
            }
        } catch {
            return nil
        }
    }
    
    func cancel() {
        sessionTask?.cancel()
    }
    
    deinit {
        observation?.invalidate()
    }
}

