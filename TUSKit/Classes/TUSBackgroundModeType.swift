//
//  TUSBackgroundMode.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 25.02.21.
//

import Foundation

public enum TUSBackgroundMode: Int {
    /// This tries to upload everything that is in the queue
    /// even if the app goes into background. The problem is,
    /// that the background processing can be shut down, so
    /// the queue won't finish. In this case you need to
    /// resume the queue on your own when the app is started again.
    case PreferUploadQueue = 0
    /// This is the default. It means that it tries to finish
    /// the current upload task and then stop.
    /// This is prefered, as its more likely to finish one upload
    /// than the whole queue. Plus it is more battery friendly,
    /// as the app will spend less time processing in the background.
    case PreferFinishUpload = 1
}
