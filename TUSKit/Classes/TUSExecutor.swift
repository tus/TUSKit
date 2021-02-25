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
                                 andFilename: upload.id,
                                 andHeaders: ["Upload-Extension": "creation", "Upload-Metadata": upload.encodedMetadata])

        let task = TUSClient.shared.tusSession.session.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "File %@ created", upload.id))
                    // Set the new status and other props for the upload
                    upload.status = .created
//                    upload.contentLength = httpResponse.allHeaderFields["Content-Length"] as? String
                    upload.uploadLocationURL = URL(string: httpResponse.allHeaderFieldsUpper()["LOCATION"]!, relativeTo: TUSClient.shared.uploadURL)
                    // Begin the upload
                    TUSClient.shared.updateUpload(upload)
                    self.upload(forUpload: upload)
                }
            }
        }
        task.resume()
    }

    internal func upload(forUpload upload: TUSUpload) {
        /*
         If the Upload is from a file, turn into data.
         Loop through until file is fully uploaded and data range has been completed. On each successful chunk, save file to defaults
         */
        // First we create chunks

        // MARK: FIX THIS

        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Preparing upload data for file %@", upload.id))
        let uploadData = try! Data(contentsOf: URL(fileURLWithPath: String(format: "%@%@%@", TUSClient.shared.fileManager.fileStorePath(), upload.id, upload.fileType!)))
//        let fileName = String(format: "%@%@", upload.id, upload.fileType!)
//        let tusName = String(format: "TUS-%@", fileName)
        // let uploadData = try! UserDefaults.standard.data(forKey: tusName)
        // upload.data = uploadData
//        let chunks: [Data] = createChunks(forData: uploadData)
//        print(chunks.count)

        let chunks = dataIntoChunks(data: uploadData,
                                    chunkSize: TUSClient.shared.chunkSize * 1024 * 1024)
        // Then we start the upload from the first chunk
        uploadInBackground(forChunks: chunks, withUpload: upload, atPosition: 0)
    }

    /**
     Will perform the upload of chunk data. It is optimized to run in the background.
     https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/extending_your_app_s_background_execution_time
     */
    private func uploadInBackground(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition _: Int) {
        // Perform the task on a background queue.
        DispatchQueue.global().async {
            // Request the task assertion and save the ID.
            self.pendingBackgrounTaskIDs[upload.id] = UIApplication.shared.beginBackgroundTask(withName: "TUS Uploading chunk") {
                // End the task if time expires.
                UIApplication.shared.endBackgroundTask(self.pendingBackgrounTaskIDs[upload.id]!)
                self.cancel(forUpload: upload, error: nil)
                self.pendingBackgrounTaskIDs[upload.id] = .invalid
            }

            // Send the data synchronously.
            self.upload(forChunks: chunks, withUpload: upload, atPosition: 0) { success in
                if !success {
                    self.cancel(forUpload: upload, error: nil)
                }
                // End the task assertion.
                UIApplication.shared.endBackgroundTask(self.pendingBackgrounTaskIDs[upload.id]!)
                self.pendingBackgrounTaskIDs[upload.id] = .invalid
            }
        }
    }

    private func upload(forChunks chunks: [Data], withUpload upload: TUSUpload, atPosition position: Int, completion: @escaping (Bool) -> Void) -> URLSessionUploadTask {
        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Upload starting for file %@ - Chunk %u / %u", upload.id, position + 1, chunks.count))

        func markAsFailed(upload: TUSUpload, error: Error?) {
            cancel(forUpload: upload, error: error)
            TUSClient.shared.status = .ready
            completion(false)
            if TUSClient.shared.currentUploads!.count > 0 {
                TUSClient.shared.createOrResume(forUpload: TUSClient.shared.currentUploads![0])
            }
        }

        let request: URLRequest = urlRequest(withFullURL: upload.uploadLocationURL!, andMethod: "PATCH", andContentLength: upload.contentLength!, andUploadLength: nil, andFilename: upload.id, andHeaders: ["Content-Type": "application/offset+octet-stream", "Upload-Offset": upload.uploadOffset!, "Content-Length": String(chunks[position].count), "Upload-Metadata": upload.encodedMetadata])

        let task = TUSClient.shared.tusSession.session.uploadTask(with: request, from: chunks[position], completionHandler: { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200 ..< 300:
                    // success
                    if chunks.count > position + 1 {
                        upload.uploadOffset = httpResponse.allHeaderFieldsUpper()["UPLOAD-OFFSET"]
                        TUSClient.shared.updateUpload(upload)
                        let taskForNextChunk = self.upload(forChunks: chunks, withUpload: upload, atPosition: position + 1, completion: completion)
                        self.pendingUploadTasks[upload.id] = taskForNextChunk
                    } else
                    if httpResponse.statusCode == 204 {
                        TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "Chunk %u / %u complete", position + 1, chunks.count))
                        if position + 1 == chunks.count {
                            TUSClient.shared.logger.log(forLevel: .Info, withMessage: String(format: "File %@ uploaded at %@", upload.id, upload.uploadLocationURL!.absoluteString))
                            self.pendingUploadTasks.removeValue(forKey: upload.id)
                            TUSClient.shared.updateUpload(upload)
                            TUSClient.shared.delegate?.TUSSuccess(forUpload: upload)
                            TUSClient.shared.cleanUp(forUpload: upload)
                            TUSClient.shared.status = .ready

                            let uploadWholeQueueInBackground = TUSClient.config?.backgroundMode == TUSBackgroundMode.PreferUploadQueue
                            let isAppBackground = UIApplication.shared.applicationState == .background

                            // Run next task for uploading, when there are any.
                            // Don't run next tasks when app is in background and upload mode is not `TUSBackgroundMode.PreferUploadQueue`
                            if TUSClient.shared.currentUploads!.count > 0 && (uploadWholeQueueInBackground || !isAppBackground) {
                                TUSClient.shared.createOrResume(forUpload: TUSClient.shared.currentUploads![0])
                            } else {
                                completion(true)
                            }
                        }
                    }
                case 400 ..< 500:
                    // reuqest error
                    markAsFailed(upload: upload, error: nil)
                case 500 ..< 600:
                    // server
                    markAsFailed(upload: upload, error: nil)
                default: break
                }
            }
        })
        pendingUploadTasks[upload.id] = task
        task.resume()
        return task
    }

    internal func cancel(forUpload upload: TUSUpload, error _: Error?) {
        let task = pendingUploadTasks[upload.id]
        if task == nil {
            TUSClient.shared.logger.log(forLevel: .Error, withMessage: String(format: "No pending task detected for the upload you are trying to cancel.", upload.id))
            return
        }
        upload.status = .canceled
        TUSClient.shared.updateUpload(upload)
        TUSClient.shared.delegate?.TUSFailure(forUpload: upload, withResponse: TUSResponse(message: "Upload was canceled."), andError: nil)
        task?.cancel()
    }

    private func dataIntoChunks(data: Data, chunkSize: Int) -> [Data] {
        var chunks = [Data]()
        var chunkStart = 0
        while chunkStart < data.count {
            let remaining = data.count - chunkStart
            let nextChunkSize = min(chunkSize, remaining)
            let chunkEnd = chunkStart + nextChunkSize

            chunks.append(data.subdata(in: chunkStart ..< chunkEnd))

            chunkStart = chunkEnd
        }
        return chunks
    }

    // MARK: Private Networking / Other methods

    internal func get(forUpload upload: TUSUpload) {
        var request = URLRequest(url: upload.uploadLocationURL!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        let task = TUSClient.shared.tusSession.session.downloadTask(with: request) { _, response, _ in
            TUSClient.shared.logger.log(forLevel: .Info, withMessage: response!.description)
        }
    }
}
