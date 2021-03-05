//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//
import Foundation

// Return nil in case accessing an index of an array that
// is out of range. See https://stackoverflow.com/a/37225027/3668241
extension Collection where Indices.Iterator.Element == Index {
    subscript(safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

public class TUSClient: NSObject, URLSessionTaskDelegate {
    // MARK: Properties

    internal var tusSession = TUSSession()
    public var uploadURL: URL
    public var delegate: TUSDelegate?
    public var applicationState: UIApplication.State
    private let executor: TUSExecutor
    internal let fileManager = TUSFileManager()
    public static let shared = TUSClient()
    public static var config: TUSConfig?
    internal var logger: TUSLogger
    public var chunkSize: Int = TUSConstants.chunkSize * 1024 * 1024 // Default chunksize can be overwritten
    // TODO: Fix this
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
    
    /// Returns all uploads that are not marked as failed
    public func pendingUploads() -> [TUSUpload] {
        if currentUploads == nil {
            return []
        }
        return currentUploads!.filter({ (_upload) -> Bool in
            return _upload.status != .failed && _upload.status != .finished
        })
    }

    internal func currentUploadsHas(element: TUSUpload) -> Bool {
        let index = currentUploads?.firstIndex(where: { (_element) -> Bool in
            _element.id == element.id
        })
        return index != nil
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

    // MARK: Initializers

    public class func setup(with config: TUSConfig) {
        TUSClient.config = config
    }

    override private init() {
        guard let config = TUSClient.config else {
            fatalError("Error - you must call setup before accessing TUSClient")
        }
        uploadURL = config.uploadURL
        executor = TUSExecutor()
        logger = TUSLogger(withLevel: config.logLevel, true)
        applicationState = .active
        fileManager.createFileDirectory()
        super.init()
        tusSession = TUSSession(customConfiguration: config.URLSessionConfig, andDelegate: self)

        // If we have already ran this library and uploads, a currentUploads object would exist,
        // if not, we'll get nil and won't be able to append. So create a blank array.
        if currentUploads == nil {
            currentUploads = []
        }

        // Listen to applicationWillTerminate events to reset queue in this case
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(notification:)),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(application:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground(application:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc
    func applicationWillTerminate(notification: Notification) {
        cancelAll()
        resetState(to: TUSClientStaus.ready)
    }
    
    @objc
    func applicationDidEnterBackground(application: UIApplication) {
        applicationState = .background
    }
    
    @objc
    func applicationWillEnterForeground(application: UIApplication) {
        applicationState = .active
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    // MARK: Create methods

    /// Create a file and upload to your TUS server with retries
    /// - Parameters:
    ///   - upload: the upload object
    ///   - retries: number of retires to take if a call fails
    public func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
        let fileName = upload.getUploadFilename()

        if fileManager.fileExists(withName: fileName) == false {
            logger.log(forLevel: .Info, withMessage: String(format: "File not found in local storage.", upload.id))
            upload.status = .new
            // avoid duplicates in upload queue
            if !currentUploadsHas(element: upload) {
                currentUploads?.append(upload)
            }
            if upload.filePath != nil {
                if fileManager.copyFile(atLocation: upload.filePath!, withFileName: fileName) == false {
                    // fail out
                    logger.log(forLevel: .Error, withMessage: String(format: "Failed to move file.", upload.id))
                    TUSClient.shared.delegate?.TUSFailure(forUpload: upload, withResponse: TUSResponse(message: "Failed to move file."), andError: nil)
                    cleanUp(forUpload: upload)
                    return
                }
            } else if upload.data != nil {
                if fileManager.writeData(withData: upload.data!, andFileName: fileName) == false {
                    // fail out
                    logger.log(forLevel: .Error, withMessage: String(format: "Failed to create file in local storage from data.", upload.id))
                    TUSClient.shared.delegate?.TUSFailure(forUpload: upload, withResponse: TUSResponse(message: "Failed to create file in local storage from data."), andError: nil)
                    cleanUp(forUpload: upload)
                    return
                }
            }
        } else {
            // The file exists, that means that an upload with the same ID & file type
            // has been executed earlier.
            // We get the earlier upload from the currentUploads:
            // - if the information has been changed we will remove
            //   the earlier upload, remove the upload file, and re-run createOrResume.
            let earlierUpload = currentUploads?.first(where: { (_upload) -> Bool in
                return _upload.id == upload.id
            })
            if (earlierUpload != nil) {
                // check whether they deep equal (see TUSUpload+isEqual)
                if (earlierUpload != upload) {
                    // objects do not equal, upload information have changed.
                    // clean earlier upload and reschedule this upload
                    logger.log(forLevel: .Info, withMessage: String(format: "Upload with id %@ already exists, but payload data are different. Cleanup old upload and reschedule the upload with new payload.", upload.id))
                    cleanUp(forUpload: earlierUpload!)
                    createOrResume(forUpload: upload, withRetries: retries)
                    return
                }
            }
        }

        if status == .ready {
            status = .uploading
            
            // if upload.status is canceled or paused, reset it to its previous state
            if (upload.status == TUSUploadStatus.canceled || upload.status == TUSUploadStatus.paused) {
                // the file was uploading when it got canceled -> we reset it to .creating
                if (upload.prevStatus == TUSUploadStatus.uploading) {
                    upload.status = .created
                } else {
                    upload.status = upload.prevStatus
                }
                TUSClient.shared.updateUpload(upload)
            }
            
            switch upload.status {
            case .created:
                logger.log(forLevel: .Info, withMessage: String(format: "File %@ has been previously been created", upload.id))
                executor.uploadInBackground(upload: upload)
            case .new:
                logger.log(forLevel: .Info, withMessage: String(format: "Creating file %@ on server", upload.getUploadFilename()))
                upload.contentLength = "0"
                upload.uploadOffset = "0"
                upload.uploadLength = String(fileManager.sizeForLocalFilePath(filePath: String(format: "%@%@", fileManager.fileStorePath(), fileName)))
                executor.create(forUpload: upload)
            default:
                status = .ready
                logger.log(forLevel: .Error, withMessage: String(format: "Unhandled status %@ of upload in #createOrResume.", upload.status?.rawValue ?? "NO STATUS SET"))
            }
        }
    }

    /// Create a file and upload to your TUS server without retries
    /// - Parameter upload: the upload object
    public func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }

    /// Create a file and upload to your TUS server with custom headers
    /// - Parameters:
    ///   - upload: rhe upload object
    ///   - headers: a dictionary of custom headers to send with the create/upload
    public func createOrResume(forUpload upload: TUSUpload, withCustomHeaders headers: [String: String]) {
        executor.customHeaders = headers
        createOrResume(forUpload: upload, withRetries: 0)
    }

    public func createOrResume(forUpload upload: TUSUpload, withCustomHeaders headers: [String: String], andFileURL _: URL) {
        executor.customHeaders = headers
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

    /// Same as cancelAll
    public func pauseAll() {
        for upload in currentUploads! {
            cancel(forUpload: upload)
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
        executor.uploadInBackground(upload: upload)
    }

    //Same as cancel
    public func pause(forUpload upload: TUSUpload) {
        cancel(forUpload: upload)
    }

    /// Cancel an upload
    /// - Parameter upload: the upload object
    public func cancel(forUpload upload: TUSUpload) {
        executor.cancel(forUpload: upload, error: nil)
    }

    /// Delete temporary files for an upload and removes it from the
    /// current uploads.
    /// - Parameter upload: the upload object
    public func cleanUp(forUpload upload: TUSUpload) {
        // Remove from current uploads
        let index = currentUploads?.firstIndex(where: { (_upload) -> Bool in
            _upload.id == upload.id
        })
        if index != nil {
            currentUploads?.remove(at: index!)
        }

        // Try to delete any tmp files
        let fileName = String(format: "%@%@", upload.id, upload.fileType!)
        if (fileManager.deleteFile(withName: fileName)) {
            logger.log(forLevel: .Info, withMessage: "file \(upload.id) cleaned up")
        } else {
            logger.log(forLevel: .Error, withMessage: "file \(upload.id) failed cleaned up")
        }
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didSendBodyData _: Int64, totalBytesSent: Int64, totalBytesExpectedToSend _: Int64) {
        let pendingUploads = self.pendingUploads()
        guard let upload = pendingUploads[safe: 0] else {
            // ignore?
            return
        }

        // Notify progress for specific upload
        delegate?.TUSProgress(forUpload: upload, bytesUploaded: Int(upload.uploadOffset ?? "0")! + Int(totalBytesSent), bytesRemaining: Int(upload.uploadLength ?? "0")!)

        // Notify  progress for global uploads
        let totalUploadedBytes = pendingUploads.reduce(0) { prev, _upload in prev + (Int(_upload.uploadOffset ?? "0")!) }
        let totalBytes = pendingUploads.reduce(0) { prev, _upload in prev + (Int(_upload.uploadLength ?? "0")!) }

        if (totalBytes > 0) {
            delegate?.TUSProgress(bytesUploaded: totalUploadedBytes + Int(totalBytesSent), bytesRemaining: totalBytes)
        }
    }

    // MARK: Methods for already uploaded files

    public func getFile(forUpload upload: TUSUpload) {
        executor.get(forUpload: upload)
    }

    // MARK: Helpers

    /// Reset the state of TUSClient - maily used for debugging, can be very destructive
    /// - Parameter newState: the new state
    func resetState(to newState: TUSClientStaus) {
        status = newState
    }

    // TODO: Update the persistance
    /// Update an uploads data, used for persistence - not useful outside of the library
    /// - Parameter upload: the upload object
    func updateUpload(_ upload: TUSUpload) {
        let needleUploadIndex = currentUploads?.firstIndex(where: { $0.id == upload.id })
        if needleUploadIndex == nil {
            TUSClient.shared.logger.log(forLevel: .Error, withMessage: String(format: "Failed to update upload, as it hasn't been found in currentUploads.", upload.id))
            return
        }

        currentUploads![needleUploadIndex!] = upload
        let updated = currentUploads
        currentUploads = updated
    }
}
