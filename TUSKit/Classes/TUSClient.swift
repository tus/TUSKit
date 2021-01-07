//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//
import Foundation


public class TUSClient: NSObject, URLSessionTaskDelegate {

    
    // MARK: Properties
    
    internal var tusSession: TUSSession = TUSSession()
    public var uploadURL: URL 
    public var delegate: TUSDelegate?
    private let executor: TUSExecutor
    internal let fileManager: TUSFileManager = TUSFileManager()
    static public let shared = TUSClient()
    private static var config: TUSConfig?
    internal var logger: TUSLogger
    public var chunkSize: Int = TUSConstants.chunkSize //Default chunksize can be overwritten
    //TODO: Fix this
    public var currentUploads: [TUSUpload]?
    {
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
        executor = TUSExecutor()
        logger = TUSLogger(withLevel: config.logLevel, true)
        fileManager.createFileDirectory()
        super.init()
        tusSession = TUSSession(customConfiguration: config.URLSessionConfig, andDelegate: self)
        
        //If we have already ran this library and uploads, a currentUploads object would exist,
        //if not, we'll get nil and won't be able to append. So create a blank array.
        if (currentUploads == nil) {
            currentUploads = []
        }
        
    }
    
    // MARK: Create methods
    
    /// Create a file and upload to your TUS server with retries
    /// - Parameters:
    ///   - upload: the upload object
    ///   - retries: number of retires to take if a call fails
    public func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
        let fileName = String(format: "%@%@", upload.id, upload.fileType!)
        let tusName = String(format: "TUS-%@", fileName)
        
        
        if (fileManager.fileExists(withName: fileName) == false) {
            logger.log(forLevel: .Info, withMessage:String(format: "File not found in local storage.", upload.id))
            upload.status = .new
            currentUploads?.append(upload)
            if (upload.filePath != nil) {
                if fileManager.moveFile(atLocation: upload.filePath!, withFileName: fileName) == false{
                    //fail out
                    logger.log(forLevel: .Error, withMessage:String(format: "Failed to move file.", upload.id))

                    return
                }
            } else if(upload.data != nil) {
                if fileManager.writeData(withData: upload.data!, andFileName: fileName) == false {
                    //fail out
                    logger.log(forLevel: .Error, withMessage:String(format: "Failed to create file in local storage from data.", upload.id))

                    return
                }
            }
        }
         
        
        if (status == .ready) {
            status = .uploading
            
            switch upload.status {
            case .paused, .created:
                logger.log(forLevel: .Info, withMessage:String(format: "File %@ has been previously been created", upload.id))
                executor.upload(forUpload: upload)
                break
            case .new:
                logger.log(forLevel: .Info, withMessage:String(format: "Creating file %@ on server", upload.id))
                upload.contentLength = "0"
                upload.uploadOffset = "0"
                upload.uploadLength = String(fileManager.sizeForLocalFilePath(filePath: String(format: "%@%@", fileManager.fileStorePath(), fileName)))
                //currentUploads?.append(upload) //Save before creating on server
                executor.create(forUpload: upload)
                break
            default:
                print()
            }
        }
    }
    
    /// Create a file and upload to your TUS server without retries
    /// - Parameter upload: the upload object
   public  func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    /// Create a file and upload to your TUS server with custom headers
    /// - Parameters:
    ///   - upload: rhe upload object
    ///   - headers: a dictionary of custom headers to send with the create/upload
    public  func createOrResume(forUpload upload: TUSUpload, withCustomHeaders headers: [String: String]) {
        self.executor.customHeaders = headers
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    public  func createOrResume(forUpload upload: TUSUpload, withCustomHeaders headers: [String: String], andFileURL fileURL: URL) {
        self.executor.customHeaders = headers
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    // MARK: Mass methods
    
    /// Resume all uploads
    public func resumeAll() {
        for upload in currentUploads! {
            createOrResume(forUpload: upload)
        }
    }
    
    /// Retry all uploads, even ones that failed
    public func retryAll() {
        for upload in currentUploads! {
            retry(forUpload: upload)
        }
    }
    
    /// Cancel all uploads
    public func cancelAll() {
        for upload in currentUploads! {
            cancel(forUpload: upload)
        }
    }
    
    /// Delete all temporary files
    public func cleanUp() {
        for upload in currentUploads! {
            cleanUp(forUpload: upload)
        }
    }
    
    
    // MARK: Methods for one upload
    
    /// Retry an upload
    /// - Parameter upload: the upload object
    public func retry(forUpload upload: TUSUpload) {
        executor.upload(forUpload: upload)
    }
    
    /// Cancel an upload
    /// - Parameter upload: the upload object
    public func cancel(forUpload upload: TUSUpload) {
        executor.cancel(forUpload: upload)
    }
    
    /// Delete temporary files for an upload
    /// - Parameter upload: the upload object
    public func cleanUp(forUpload upload: TUSUpload) {
        //Delete stuff here
        let fileName = String(format: "%@%@", upload.id, upload.fileType!)
        currentUploads?.remove(at: 0)
        fileManager.deleteFile(withName: fileName)
        logger.log(forLevel: .Info, withMessage: "file \(upload.id) cleaned up")
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        var upload = currentUploads![0]
        self.delegate?.TUSProgress(bytesUploaded: Int(upload.uploadOffset!)!, bytesRemaining: Int(upload.uploadLength!)!)
    }
    
    // MARK: Methods for already uploaded files
    
    public func getFile(forUpload upload: TUSUpload) {
        executor.get(forUpload: upload)
    }

    
    //MARK: Helpers
    
    /// Reset the state of TUSClient - maily used for debugging, can be very destructive
    /// - Parameter newState: the new state
    func resetState(to newState: TUSClientStaus) {
        self.status = newState
    }
    
    //TODO: Update the persistance
    /// Update an uploads data, used for persistence - not useful outside of the library
    /// - Parameter upload: the upload object
    func updateUpload(_ upload: TUSUpload) {
        let needleUploadIndex = currentUploads?.firstIndex(where: { $0.id == upload.id })
        currentUploads![needleUploadIndex!] = upload
        var updated = currentUploads
        self.currentUploads = updated
    }
    
}
