//
//  File.swift
//  
//
//  Created by 𝗠𝗮𝗿𝘁𝗶𝗻 𝗟𝗮𝘂 on 2023-05-04.
//

import Foundation

public struct TusServerInfo {
    public let version: String?

    public let maxSize: Int?

    public let extensions: [TUSProtocolExtension]?

    public let supportedVersions: [String]

    public let supportedChecksumAlgorithms: [String]?

    public let supportsDelete: Bool
    
    init(version: String, maxSize: Int?, extensions: [TUSProtocolExtension]?, supportedVersions: [String], supportedChecksumAlgorithms: [String]?) {
        self.version = version
        self.maxSize = maxSize
        self.extensions = extensions
        self.supportedVersions = supportedVersions
        self.supportedChecksumAlgorithms = supportedChecksumAlgorithms
        self.supportsDelete = extensions?.contains(.termination) ?? false
    }
}
