//
//  TUSWrapper.swift
//  TUSKitExample
//
//  Created by Donny Wals on 27/02/2023.
//

import Foundation
import TUSKit

enum UploadStatus {
    case paused(bytesUploaded: Int, totalBytes: Int)
    case uploading(bytesUploaded: Int, totalBytes: Int)
    case failed(error: Error)
    case uploaded(url: URL)
}

class TUSWrapper: TUSClientDelegate, ObservableObject {
    let client: TUSClient
    
    @MainActor
    @Published private(set) var uploads: [UUID: UploadStatus] = [:]
    
    init(client: TUSClient) {
        self.client = client
        client.delegate = self
    }
    
    @MainActor
    func pauseUpload(id: UUID) {
        try? client.cancel(id: id)
        
        if case let .uploading(bytesUploaded, totalBytes) = uploads[id] {
            uploads[id] = .paused(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
        }
    }
    
    @MainActor
    func resumeUpload(id: UUID) {
        _ = try? client.retry(id: id)
        
        if case let .paused(bytesUploaded, totalBytes) = uploads[id] {
            uploads[id] = .uploading(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
        }
    }
    
    @MainActor
    func clearUpload(id: UUID) {
        _ = try? client.cancel(id: id)
        _ = try? client.removeCacheFor(id: id)
        uploads[id] = nil
    }
    
    func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        Task { @MainActor in
            uploads[id] = .uploading(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
        }
    }
    
    func didStartUpload(id: UUID, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            uploads[id] = .uploading(bytesUploaded: 0, totalBytes: Int.max)
        }
    }
    
    func didFinishUpload(id: UUID, url: URL, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            uploads[id] = .uploaded(url: url)
        }
    }
    
    func uploadFailed(id: UUID, error: Error, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            uploads[id] = .failed(error: error)
            
            if case TUSClientError.couldNotUploadFile(underlyingError: let underlyingError) = error,
               case TUSAPIError.failedRequest(let response) = underlyingError {
                print("upload failed with response \(response)")
            }
        }
    }
    
    func fileError(error: TUSClientError, client: TUSClient) { }
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) { }
}
