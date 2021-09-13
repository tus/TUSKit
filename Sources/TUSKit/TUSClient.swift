//
//  TUSClient.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

// TODO: Why not an enum? Adding cases...
public struct TUSClientError: Error {
    let code: Int
    
    public static var fileDoesNotExist = TUSClientError(code: 1)
}

/// The TUSKit client.
///
/// Use this type to initiate uploads.
///
/// ## Example
///
///     let client = TUSClient(config: TUSConfig(server: liveDemoPath))
public final class TUSClient {
    
    private let config: TUSConfig
    
    public init(config: TUSConfig) {
        self.config = config
    }
    
    @discardableResult
    public func addUploadTask(filePath: URL) throws -> UploadTask {
        guard FileManager.default.fileExists(atPath: filePath.absoluteString) else {
            throw TUSClientError.fileDoesNotExist
        }
        
        return UploadTask(source: .filePath(filePath))
    }
    
    @discardableResult
    public func addUploadTask(data: Data) -> UploadTask {
        return UploadTask(source: .data(data))
    }
    
}

public final class UploadTask {
    
    enum Source {
        case filePath(URL)
        case data(Data)
    }
    
    let source: Source
    
    init(source: Source) {
        self.source = source
    }
}

public struct TUSConfig {
    let server: URL
    
    public init(server: URL) {
        self.server = server
    }
}
