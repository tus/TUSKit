//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

public class TUSClient: NSObject, URLSessionTaskDelegate {

    
    // MARK: Properties
    
    internal var tusSession: TUSSession = TUSSession()
    public var uploadURL: URL?
    public var delegate: TUSDelegate?
    private let executor: TUSExecutor
    internal let fileManager: TUSFileManager = TUSFileManager()
    static public let shared = TUSClient()
    private static var config: TUSConfig?
    internal var logger: TUSLogger
    public var chunkSize: Int = TUSConstants.chunkSize //Default chunksize can be overwritten
    public var currentUploads: [TUSUpload]?
    //TODO: Fix this
//    public var currentUploads: [TUSUpload]? {
//        get {
//            guard let data = UserDefaults.standard.object(forKey: TUSConstants.kSavedTUSUploadsDefaultsKey) as? Data else {
//                return nil
//            }
//            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [TUSUpload]
//        }
//        set(currentUploads) {
//            let data = NSKeyedArchiver.archivedData(withRootObject: currentUploads!)
//            UserDefaults.standard.set(data, forKey: TUSConstants.kSavedTUSUploadsDefaultsKey)
//        }
//    }
    
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
        executor = TUSExecutor()
        logger = TUSLogger(config.debugLogEnabled)
        fileManager.createFileDirectory()
        super.init()
        tusSession = TUSSession(customConfiguration: config.URLSessionConfig, andDelegate: self)
        currentUploads = []

    }
    
    // MARK: Create methods
    
    public func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
        currentUploads?.append(upload)
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
            logger.log(String(format: "File %@ has been previously been created", upload.id!))
            executor.upload(forUpload: upload)
            break
        case .new:
            logger.log(String(format: "Creating file %@ on server", upload.id!))
            upload.contentLength = "0"
            upload.uploadOffset = "0"
            upload.uploadLength = String(fileManager.sizeForLocalFilePath(filePath: String(format: "%@%@", fileManager.fileStorePath(), fileName)))
            executor.create(forUpload: upload)
            break
        default:
            print()
        }
    }
    
   public  func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    // MARK: Mass methods
    
    public func resumeAll() {
        for upload in currentUploads! {
            createOrResume(forUpload: upload)
        }
    }
    
    public func retryAll() {
        for upload in currentUploads! {
            retry(forUpload: upload)
        }
    }
    
    public func cancelAll() {
        for upload in currentUploads! {
            cancel(forUpload: upload)
        }
    }
    
    public func cleanUp() {
        for upload in currentUploads! {
            cleanUp(forUpload: upload)
        }
    }
    
    
    // MARK: Methods for one upload
    
    public func retry(forUpload upload: TUSUpload) {
        executor.upload(forUpload: upload)
    }
    
    public func cancel(forUpload upload: TUSUpload) {
        executor.cancel(forUpload: upload)
    }
    
    public func cleanUp(forUpload upload: TUSUpload) {
        //Delete stuff here
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        var upload = currentUploads![0]
        self.delegate?.TUSProgress(bytesUploaded: Int(upload.uploadOffset!)!, bytesRemaining: Int(upload.uploadLength!)!)
    }
    
}
