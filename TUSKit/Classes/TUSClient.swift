//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

public class TUSClient: NSObject {
    
    // MARK: Properties
    
    var session: URLSession?
    var uploadURL: URL?
    var delegate: TUSDelegate?
    private let executor: TUSExecutor = TUSExecutor()
    private let fileManager: TUSFileManager = TUSFileManager()
    static public let shared = TUSClient()
    private static var config: TUSConfig?
    private var chunckSize: Int = TUSConstants.chunkSize //Default chunksize can be overwritten
    
    public var currentUploads: [TUSUpload]? {
        get {
            guard let data = UserDefaults.standard.object(forKey: TUSConstants.kSavedTUSUploadsDefaultsKey) as? Data else {
                return nil
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [TUSUpload]
        }
        set(currentUploads) {
            let data = NSKeyedArchiver.archivedData(withRootObject: currentUploads!)
            UserDefaults.standard.set(data, forKey: TUSConstants.kSavedTUSUploadsDefaultsKey)
        }
    }
    
    public var status: TUSClientStaus? {
        get {
            guard let status = UserDefaults.standard.value(forKey: TUSConstants.kSavedTUSClientStatusDefaultsKey) as? String else {
                return .ready
            }
            return TUSClientStaus(rawValue: status)
        }
        set(status) {
            UserDefaults.standard.set(status?.rawValue, forKey: String(format: "%@", TUSConstants.kSavedTUSClientStatusDefaultsKey))
        }
    }
    
    //MARK: Initializers
    public class func setup(with config:TUSConfig){
        TUSClient.config = config
    }

    private override init() {
        guard let config = TUSClient.config else {
            fatalError("Error - you must call setup before accessing TUSClient")
        }
        uploadURL = config.uploadURL
        session = URLSession(configuration: config.URLSessionConfig)
    }
    
    // MARK: Create methods
    
    func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
        let fileName = String(format: "%@%@", upload.id!, upload.fileType!)
        if (fileManager.fileExists(withName: fileName) == false) {
            if (upload.filePath != nil) {
                fileManager.moveFile(atLocation: upload.filePath!, withFileName: fileName)
            } else if(upload.data != nil) {
                fileManager.writeData(withData: upload.data!, andFileName: fileName)
            }
        }
        
        switch upload.status {
        case .paused, .created:
            executor.upload(forUpload: upload, withChunkSizeInMB: chunckSize)
            break
        case .new:
            executor.create(forUpload: upload)
            break
        default:
            print()
        }
    }
    
    func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    // MARK: Mass methods
    
    func resumeAll() {
        for upload in currentUploads! {
            createOrResume(forUpload: upload)
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
    
    
    // MARK: Methods for one upload
    
    func retry(forUpload upload: TUSUpload) {
        executor.upload(forUpload: upload, withChunkSizeInMB: chunckSize)
    }
    
    func cancel(forUpload upload: TUSUpload) {
        executor.cancel(forUpload: upload)
    }
    
    func cleanUp(forUpload upload: TUSUpload) {
        //Delete stuff here
    }
    
    
    
}
