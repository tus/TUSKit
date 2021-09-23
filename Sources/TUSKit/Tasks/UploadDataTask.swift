//
//  UploadDataTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// The upload task will upload to data a destination.
/// Will spawn more UploadDataTasks if an upload isn't complete.
final class UploadDataTask: Task {
    
    let api: TUSAPI
    let metaData: UploadMetadata
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
            // Improve: Enrich error
            // TODO: Delete file?
            assertionFailure("Ended up with an empty range to upload.")
            throw TUSClientError.couldNotUploadFile
        }
        
        if (range?.count ?? 0) > metaData.size {
            // Improve: Enrich error
            assertionFailure("The range to upload is larger than the size")
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
       
        api.upload(data: dataToUpload, range: range, location: remoteDestination) { [unowned self] result in
            do {
                let offset = try result.get()
                metaData.uploadedRange = 0..<offset
                try Files.encodeAndStore(metaData: metaData)
                
                let hasFinishedUploading = offset == metaData.size
                if hasFinishedUploading {
                    completed(.success([]))
                    return
                }
                
                let task: UploadDataTask
                if let range = range {
                    let chunkSize = range.count
                    let nextRange = offset..<min((offset + chunkSize), metaData.size)
                    task = try UploadDataTask(api: api, metaData: metaData, range: nextRange)
                } else {
                    task = try UploadDataTask(api: api, metaData: metaData)
                    
                }
                completed(.success([task]))
            } catch let error as TUSClientError {
                completed(.failure(error))
            } catch {
                completed(.failure(TUSClientError.couldNotUploadFile))
            }
            
        }
    }
}
