//
//  TUSConfig.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/6/20.
//

import Foundation

public struct TUSConfig {
    var uploadURL: URL
    var URLSessionConfig: URLSessionConfiguration = URLSessionConfiguration.default
    public var logLevel: TUSLogLevel = .Off
    public var backgroundMode: TUSBackgroundMode = .PreferFinishUpload
    
    public init(withUploadURLString uploadURLString: String, andSessionConfig sessionConfig: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.uploadURL = URL(string: uploadURLString)!
        self.URLSessionConfig = sessionConfig
    }
    
    public init(withUploadURL uploadURL: URL, andSessionConfig sessionConfig: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.uploadURL = uploadURL
        self.URLSessionConfig = sessionConfig
    }
}
