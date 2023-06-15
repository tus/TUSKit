//
//  File.swift
//  
//
//  Created by 𝗠𝗮𝗿𝘁𝗶𝗻 𝗟𝗮𝘂 on 2023-05-04.
//

import Foundation

public struct TusServerInfo {
    public private(set) var version: String?
    
    public private(set) var maxSize: Int?
    
    public private(set) var extensions: [TUSProtocolExtension]?
    
    public private(set) var supportedVersions: [String]
    
    public private(set) var supportedChecksumAlgorithms: [String]?
    
    public var supportsDelete: Bool {
        extensions?.contains(.termination) ?? false
    }
    
    init(version: String, maxSize: Int?, extensions: [TUSProtocolExtension]?, supportedVersions: [String], supportedChecksumAlgorithms: [String]?) {
        self.version = version
        self.maxSize = maxSize
        self.extensions = extensions
        self.supportedVersions = supportedVersions
        self.supportedChecksumAlgorithms = supportedChecksumAlgorithms
    }
}
