//
//  TUSUploadStatus.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public enum TUSUploadStatus: String, Codable {
    case new
    case created
    case uploading
    case paused
    case canceled
    case finished
}
