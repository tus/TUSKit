//
//  TUSUploadStatus.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public enum TUSUploadStatus: String {
    case new = "new"
    case created = "created"
    case uploading = "uploading"
    case paused = "paused"
    case canceled = "canceled"
    case failed = "failed"
    case finished = "finished"
}
