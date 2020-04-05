//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

class TUSClient: NSObject {

    var uploadURL: URL?
    var delegate: TUSDelegate?
    var currentUploads: [TUSUpload]?
    var currentStatus: TUSUploadStatus?
    
    init(withUploadURLString uploadURLString: String) {
        super.init()
        self.uploadURL = URL(string: uploadURLString)
    }
    
    init(withUploadURL uploadURL: URL) {
        super.init()
        self.uploadURL = uploadURL
    }
    
    func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
           //
    }
    
    func resumeAll() {
        for upload in currentUploads! {
            upload.resume()
        }
    }
    
    func retryAll() {
        for upload in currentUploads! {
            upload.retry()
        }
    }
    
    func cancelAll() {
          for upload in currentUploads! {
              upload.cancel()
          }
    }
    
    func cleanUp() {
        for upload in currentUploads! {
            upload.delete()
        }
    }
}
