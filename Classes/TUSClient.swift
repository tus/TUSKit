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
    
    // MARK: Private file storage methods
    
    private func fileStorePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory: String = paths[0]
        return documentsDirectory.appending("TUS")
    }
    
    private func createFileDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: fileStorePath(), withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription);
        }
    }
    
    private func moveFile(atLocation location: URL, withFileName name: String) {
        do {
            try FileManager.default.moveItem(at: location, to: URL(string: fileStorePath().appending(name))!)
        } catch(let error){
            print(error)
        }
    }
    
    private func writeData(withData data: Data, andFileName name: String) {
        do {
            try data.write(to: URL(string: fileStorePath().appending(name))!)
        } catch (let error) {
            print(error)
        }
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
    
    // MARK: Private Networking / Upload methods
    
    
}
