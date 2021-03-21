//
//  TUSExecutor.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import Foundation

class TUSExecutor: NSObject, URLSessionDelegate {
    var customHeaders: [String: String] = [:]
    var pendingUploadTasks: [String: URLSessionUploadTask] = [:]
    var pendingBackgrounTaskIDs: [String: UIBackgroundTaskIdentifier] = [:]

    // MARK: Private Networking / Upload methods

    private func urlRequest(withFullURL url: URL, andMethod method: String, andContentLength contentLength: String?, andUploadLength uploadLength: String?, andFilename _: String, andHeaders headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.addValue(TUSConstants.TUSProtocolVersion, forHTTPHeaderField: "TUS-Resumable")

        if let contentLength = contentLength {
            request.addValue(contentLength, forHTTPHeaderField: "Content-Length")
        }

        if let uploadLength = uploadLength {
            request.addValue(uploadLength, forHTTPHeaderField: "Upload-Length")
        }

        for header in headers.merging(customHeaders, uniquingKeysWith: { current, _ in current }) {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }

        return request
    }

    /// Creates the file at the server. This is preperation for the upload.
    internal func create(forUpload upload: TUSUpload) {
        let request = urlRequest(withFullURL: TUSClient.shared.uploadURL,
                                 andMethod: "POST",
                                 andContentLength: upload.contentLength,
                                 andUploadLength: upload.uploadLength,
                                 andFilename: upload.getUploadFilename(),
                                 andHeaders: ["Upload-Extension": "creation", "Upload-Metadata": upload.encodedMetadata])

        let task = TUSClient.shared.tusSession.session.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "File %@ created", upload.getUploadFilename()))
                    // Set the new status and other props for the upload
                    upload.status = .created
                    upload.uploadLocationURL = URL(string: httpResponse.allHeaderFieldsUpper()["LOCATION"]!, relativeTo: TUSClient.shared.uploadURL)
                    // Begin the upload
                    TUSClient.shared.updateUpload(upload)
                    self.uploadInBackground(upload: upload, skipResumeCheck: true)
                } else {
                    self.cancel(forUpload: upload, error: NSError(domain: "", code: httpResponse.statusCode, userInfo: nil), failed: true)
                }
            } else {
                self.cancel(forUpload: upload, error: nil, failed: true)
            }
        }
        task.resume()
    }
    
    /// Will perform the upload of chunk data. It is optimized to run in the background.
    ///  `skipResumeCheck` (Default: false). When you set this to true the upload will start from byte position 0 of the file.
    /// https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/extending_your_app_s_background_execution_time
    internal func uploadInBackground(upload: TUSUpload, skipResumeCheck: Bool = false) {
        // Perform the task on a background queue.
        DispatchQueue.global().async {
            // Request the task assertion and save the ID.
            self.pendingBackgrounTaskIDs[upload.id] = UIApplication.shared.beginBackgroundTask(withName: "TUS Uploading chunk") {
                // End the task if time expires.
                UIApplication.shared.endBackgroundTask(self.pendingBackgrounTaskIDs[upload.id]!)
                self.cancel(forUpload: upload, error: nil)
                TUSClient.shared.status = .ready
                self.pendingBackgrounTaskIDs[upload.id] = .invalid
            }
            
            func uploadFinishedCallback(success: Bool) {
                // End the task assertion.
                UIApplication.shared.endBackgroundTask(self.pendingBackgrounTaskIDs[upload.id]!)
                self.pendingBackgrounTaskIDs[upload.id] = .invalid
            }
            
            func startUpload(chunks: [Data]) {
                upload.status = .uploading
                TUSClient.shared.updateUpload(upload)
                // we start the upload from the first chunk (position 0)
                self.upload(forChunks: chunks, withUpload: upload, atPosition: 0, completion: uploadFinishedCallback)
            }
            
            // Do the work:
            do {
                let data = try upload.getData()
                if (skipResumeCheck) {
                    let chunks = self.dataIntoChunks(data: data, chunkSize: TUSClient.shared.chunkSize)
                    startUpload(chunks: chunks)
                } else {
                    self.prepareUpload(forUpload: upload, uploadData: data) { (chunks, skipUploadMarkSuccess) in
                        if (skipUploadMarkSuccess) {
                            self.handleUploadSuccess(upload: upload, completion: uploadFinishedCallback)
                        } else {
                            startUpload(chunks: chunks)
                        }
                    }
                }
            } catch {
                self.markAsFailed(upload: upload, completion: uploadFinishedCallback, error: error)
            }
        }
    }

    /// This gets the chunks in a `Data` array that we
    /// are going to upload.
    /// `callback`  function that will be called with the chunks to upload, takes
    ///            contentOffset into account if file must be resumed.
    ///            If the second param is true, the upload can be skipped and
    ///            the upload can be marked as success (edge case if upload
    ///            was aborted when upload just finished)
    ///
    private func prepareUpload(
        forUpload upload: TUSUpload,
        uploadData: Data,
        callback: @escaping ([Data], Bool) -> Void
    ) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed.
         On each successful chunk, save file to defaults
         */

        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Preparing upload data for file %@", upload.id))
        
        // Get from which point we should start the uploading (important if the file
        // has already been partially uploaded)
        checkForResumableOffset(uploadUrl: upload.uploadLocationURL!) { (uploadOffset) in
            // Create chunks to upload, eventually starting from the uploadOffset we retrieved
            let chunks = self.dataIntoChunks(data: uploadData,
                                             chunkSize: TUSClient.shared.chunkSize,
                                        chunkStartParam: uploadOffset ?? 0)
            TUSClient.shared.logger.log(forLevel: .Debug, withMessage: String(format: "Start upload for file %@ at offset %u", upload.id, uploadOffset ?? 0))
            
            upload.uploadOffset = "\(uploadOffset ?? 0)"
            TUSClient.shared.updateUpload(upload)
            
            // EDGE CASE: UploadOffset equals ContentLength.
            // This can happen when the app was killed when the
            // upload has just finished.
            let skipUpload = (uploadOffset ?? 0) == Int(upload.uploadLength ?? "0")

            callback(chunks, skipUpload)
        }
    }

    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition position: Int, completion: @escaping (Bool) -> Void) -> URLSessionUploadTask {
        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Upload starting for file %@ - Chunk %u / %u", upload.id, position + 1, chunks.count))

        
        let request: URLRequest = urlRequest(withFullURL: upload.uploadLocationURL!, andMethod: "PATCH", andContentLength: upload.contentLength!, andUploadLength: nil, andFilename: upload.getUploadFilename(), andHeaders: ["Content-Type": "application/offset+octet-stream", "Upload-Offset": upload.uploadOffset!, "Content-Length": String(chunks[position].count), "Upload-Metadata": upload.encodedMetadata])

        let task = TUSClient.shared.tusSession.session.uploadTask(with: request, from: chunks[position], completionHandler: { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200 ..< 300:
                    // success
                    if chunks.count > position + 1 {
                        upload.uploadOffset = httpResponse.allHeaderFieldsUpper()["UPLOAD-OFFSET"]
                        TUSClient.shared.updateUpload(upload)
                        if (upload.status == TUSUploadStatus.uploading) {
                            let taskForNextChunk = self.upload(forChunks: chunks, withUpload: upload, atPosition: position + 1, completion: completion)
                            self.pendingUploadTasks[upload.id] = taskForNextChunk
                        }
                    } else
                    if httpResponse.statusCode == 204 {
                        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Chunk %u / %u complete", position + 1, chunks.count))
                        if position + 1 == chunks.count {
                            self.handleUploadSuccess(upload: upload, completion: completion)
                        }
                    }
                case 400 ..< 500:
                    // reuqest error
                    TUSClient.shared.logger.log(forLevel: .Error, withMessage: String(format: "Received request failure status code %u", httpResponse.statusCode))
                    self.markAsFailed(upload: upload, completion: completion, error: nil)
                case 500 ..< 600:
                    // server
                    TUSClient.shared.logger.log(forLevel: .Error, withMessage: String(format: "Received server failure status code %u", httpResponse.statusCode))
                    self.markAsFailed(upload: upload, completion: completion, error: nil)
                default: break
                }
            } else {
                TUSClient.shared.logger.log(forLevel: .Error, withMessage: "Server response couldn't be parsed!")
                self.markAsFailed(upload: upload, completion: completion, error: nil)
            }
        })
        pendingUploadTasks[upload.id] = task
        task.resume()
        return task
    }
    
    func handleUploadSuccess(upload: TUSUpload, completion: @escaping (Bool) -> Void) {
        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "File %@ uploaded at %@", upload.id, upload.uploadLocationURL!.absoluteString))
        self.pendingUploadTasks.removeValue(forKey: upload.id)
        TUSClient.shared.updateUpload(upload)
        TUSClient.shared.delegate?.TUSSuccess(forUpload: upload)
        TUSClient.shared.cleanUp(forUpload: upload)
        TUSClient.shared.status = .ready

        // Run next task for uploading, when there are any.
        if continueUploading() {
            let pendingUploads = TUSClient.shared.pendingUploads()
            TUSClient.shared.createOrResume(forUpload: pendingUploads[0])
        } else {
            completion(true)
        }
    }

    internal func cancel(forUpload upload: TUSUpload, error: Error?, failed: Bool = false) {
        let task = pendingUploadTasks[upload.id]
        if task != nil {
            TUSClient.shared.logger.log(forLevel: .Error, withMessage: String(format: "No pending task detected for the upload you are trying to cancel.", upload.id))
        } else {
            task?.cancel()
            pendingUploadTasks.removeValue(forKey: upload.id)
        }
        upload.status = failed ? .failed : .canceled
        TUSClient.shared.updateUpload(upload)
        TUSClient.shared.delegate?.TUSFailure(forUpload: upload, withResponse: TUSResponse(message: "Upload was canceled."), andError: error)
        TUSClient.shared.status = .ready
    }
    
    /// Checks whether there are pending uploads left and whether all constraint are okay to continue uploading
    /// Don't run next tasks when app is in background and upload mode is not `TUSBackgroundMode.PreferUploadQueue`.
    internal func continueUploading() -> Bool {
        let uploadWholeQueueInBackground = TUSClient.config?.backgroundMode == TUSBackgroundMode.PreferUploadQueue
        let isAppBackground = TUSClient.shared.applicationState == .background
        
        let pendingUploads = TUSClient.shared.pendingUploads()
        return pendingUploads.count > 0 && (uploadWholeQueueInBackground || !isAppBackground)
    }

    // TODO: Retry-Mechanism: The places where we called `markAsFailed` are the places where we could retry uploading the failed chunk.
    internal func markAsFailed(upload: TUSUpload, completion: @escaping (Bool) -> Void, error: Error?) {
        cancel(forUpload: upload, error: error, failed: true)

        if continueUploading() {
            let pendingUploads = TUSClient.shared.pendingUploads()
            TUSClient.shared.createOrResume(forUpload: pendingUploads[0])
        } else {
            completion(false)
        }
    }
}
