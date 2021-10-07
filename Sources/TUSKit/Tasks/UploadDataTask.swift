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
            // TODO: Delete file?
            assertionFailure("Ended up with an empty range to upload.")
            throw TUSClientError.couldNotUploadFile
        }
        
        if (range?.count ?? 0) > metaData.size {
            // Improve: Enrich error
            assertionFailure("The range \(String(describing: range?.count)) to upload is larger than the size \(metaData.size)")
            throw TUSClientError.couldNotUploadFile
        }
        
        if let destination = metaData.remoteDestination {
            self.metaData.remoteDestination = destination
        } else {
            // TODO: Throw. Recover from error
            fatalError("No remote destination for upload task")
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
        
        let dataToUpload: Data
        if let range = range {
            dataToUpload = data[range]
        } else {
            dataToUpload = data
        }
        
        guard let remoteDestination = metaData.remoteDestination else {
            assertionFailure("Somehow did not have a remote destination to upload to.")
            completed(Result.failure(TUSClientError.couldNotUploadFile))
            return
        }
       
        let task = api.upload(data: dataToUpload, range: range, location: remoteDestination) { [unowned self] result in
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
                    // TODO: Error logger
                    print("Server returned a new uploaded offset \(offset), but it's lower than what's already uploaded \(metaData.uploadedRange!), according to the metaData. Either the metaData is wrong, or the server is returning a wrong value offset.")
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
        
        let dataSize = data.count
        let targetRange = self.range ?? 0..<dataSize
        sessionTask = task
        if #available(iOS 11.0, macOS 10.13, *) {
            observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
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
        
    }
    
    func cancel() {
        sessionTask?.cancel()
    }
    
    deinit {
        observation?.invalidate()
    }
}

