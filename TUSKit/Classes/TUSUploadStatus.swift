//
//  TUSUploadStatus.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public enum TUSUploadStatus: String {
    case uploading = "uploading"
    case paused = "paused"
    case canceled = "canceled"
    case finished = "finished"
}
