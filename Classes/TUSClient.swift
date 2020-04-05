//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

class TUSClient: NSObject {
    
    // MARK: Properties
    
    var uploadURL: URL?
    var delegate: TUSDelegate?
    var currentUploads: [TUSUpload]?
    var currentStatus: TUSUploadStatus?
    
    //MARK: Initializers
    
    init(withUploadURLString uploadURLString: String) {
        super.init()
        self.uploadURL = URL(string: uploadURLString)
    }
    
    init(withUploadURL uploadURL: URL) {
        super.init()
        self.uploadURL = uploadURL
    }
    
    
    // MARK: Create methods
    
    func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
           //
    }
    
    
    // MARK: Methods for one upload
    
    func resume(forUpload upload: TUSUpload) {
        
    }
    
    func retry(forUpload upload: TUSUpload) {
        
    }
    
    func cancel(forUpload upload: TUSUpload) {
        
    }
    
    func cleanUp(forUpload upload: TUSUpload) {
        
    }
    
    // MARK: Mass methods
    
    func resumeAll() {
        for upload in currentUploads! {
            resume(forUpload: upload)
        }
    }
    
    func retryAll() {
        for upload in currentUploads! {
            retry(forUpload: upload)
        }
    }
    
    func cancelAll() {
         for upload in currentUploads! {
             cancel(forUpload: upload)
         }
    }
    
    func cleanUp() {
        for upload in currentUploads! {
            cleanUp(forUpload: upload)
        }
    }
    
    // MARK: Pricate Networking / Upload methods
    
    
}
