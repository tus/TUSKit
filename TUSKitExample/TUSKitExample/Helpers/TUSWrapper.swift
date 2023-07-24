//
//  TUSWrapper.swift
//  TUSKitExample
//
//  Created by Donny Wals on 27/02/2023.
//

import Foundation
import TUSKit
import SwiftUI

enum UploadStatus {
    case paused(bytesUploaded: Int, totalBytes: Int)
    case uploading(bytesUploaded: Int, totalBytes: Int)
    case failed(error: Error)
    case uploaded(url: URL)
}

class TUSWrapper: ObservableObject {
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
            withAnimation {
                uploads[id] = .paused(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
            }
        }
    }
    
    @MainActor
    func resumeUpload(id: UUID) {
        _ = try? client.retry(id: id)
        
        if case let .paused(bytesUploaded, totalBytes) = uploads[id] {
            withAnimation {
                uploads[id] = .uploading(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
            }
        }
    }
    
    @MainActor
    func clearUpload(id: UUID) {
        _ = try? client.cancel(id: id)
        _ = try? client.removeCacheFor(id: id)
        
        withAnimation {
            uploads[id] = nil
        }
    }
    
    @MainActor
    func removeUpload(id: UUID) {
        _ = try? client.removeCacheFor(id: id)
        
        withAnimation {
            uploads[id] = nil
        }
    }
}


// MARK: - TUSClientDelegate


extension TUSWrapper: TUSClientDelegate {
    func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        Task { @MainActor in
            uploads[id] = .uploading(bytesUploaded: bytesUploaded, totalBytes: totalBytes)
        }
    }
    
    func didStartUpload(id: UUID, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            withAnimation {
                uploads[id] = .uploading(bytesUploaded: 0, totalBytes: Int.max)
            }
        }
    }
    
    func didFinishUpload(id: UUID, url: URL, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            withAnimation {
                uploads[id] = .uploaded(url: url)
            }
        }
    }
    
    func uploadFailed(id: UUID, error: Error, context: [String : String]?, client: TUSClient) {
        Task { @MainActor in
            
            withAnimation {
                uploads[id] = .failed(error: error)
            }
            
            if case TUSClientError.couldNotUploadFile(underlyingError: let underlyingError) = error,
               case TUSAPIError.failedRequest(let response) = underlyingError {
                print("upload failed with response \(response)")
            }
        }
    }
    
    func fileError(error: TUSClientError, client: TUSClient) { }
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) { }
}


// MARK: - Mock upload records


extension TUSWrapper {
    @MainActor
    func setMockUploadRecords() {
        let sampleURL = URL(string: "https://www.google.com/search?client=safari&q=image&tbm=isch&sa=X&ved=2ahUKEwie6t7IyZCAAxXQcmwGHerJAG0Q0pQJegQIHhAB&biw=1680&bih=888&dpr=2#imgrc=cSb7xvw-0talCM")!
        let uploadStatusSample: [UUID: UploadStatus] = [
            UUID(): UploadStatus.uploading(bytesUploaded: 0, totalBytes: 100),
            UUID(): UploadStatus.paused(bytesUploaded: 60, totalBytes: 100),
            UUID(): UploadStatus.uploaded(url: sampleURL),
            UUID(): UploadStatus.failed(error: TUSAPIError.couldNotFetchServerInfo),
            
            UUID(): UploadStatus.uploading(bytesUploaded: 25, totalBytes: 100),
            UUID(): UploadStatus.paused(bytesUploaded: 90, totalBytes: 100),
            UUID(): UploadStatus.uploaded(url: sampleURL),
            UUID(): UploadStatus.failed(error: TUSAPIError.underlyingError(NSError(domain: "invalid offset", code: 8))),
            
            UUID(): UploadStatus.uploading(bytesUploaded: 50, totalBytes: 100),
            UUID(): UploadStatus.paused(bytesUploaded: 10, totalBytes: 100),
            UUID(): UploadStatus.uploaded(url: sampleURL),
            UUID(): UploadStatus.failed(error: TUSClientError.emptyUploadRange),
            
            UUID(): UploadStatus.uploading(bytesUploaded: 75, totalBytes: 100),
            UUID(): UploadStatus.paused(bytesUploaded: 0, totalBytes: 100),
            UUID(): UploadStatus.uploaded(url: sampleURL),
            UUID(): UploadStatus.failed(error: TUSClientError.uploadIsAlreadyFinished)
        ]
        withAnimation {
            uploads = uploadStatusSample
        }
    }
}
