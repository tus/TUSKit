//
//  TUSAPI.swift
//
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

/// The errors a TUSAPI can return
public enum TUSAPIError: Error {
    case underlyingError(Error)
    case couldNotFetchStatus
    case couldNotFetchServerInfo
    case couldNotRetrieveOffset
    case couldNotRetrieveLocation
    case failedRequest(HTTPURLResponse)
}

/// The status of an upload.
struct Status {
    let length: Int
    let offset: Int
}

/// The Uploader's responsibility is to perform work related to uploading.
/// This includes: Making requests, handling requests, handling errors.
actor TUSAPI {
    enum HTTPMethod: String {
        case head = "HEAD"
        case post = "POST"
        case get = "GET"
        case patch = "PATCH"
        case options = "OPTIONS"
        case delete = "DELETE"
    }
    
    var session: URLSession!
    private var backgroundHandler: (@Sendable () -> Void)? = nil
    private var callbacks: [String: (Result<HTTPURLResponse, Error>) -> Void] = [:]
    private var queue = DispatchQueue(label: "com.tus.TUSAPI")
    
    deinit {
        if session.delegate is SessionDataDelegate {
            session.finishTasksAndInvalidate()
        }
    }
    
    init(session: URLSession) {
        self.session = session
    }
    
    init(sessionConfiguration: URLSessionConfiguration) {
        self.session = URLSession(configuration: sessionConfiguration, delegate: SessionDataDelegate(api: self), delegateQueue: nil)
    }
    
    func serverInfo(server: URL) async throws -> TusServerInfo {
        let request = makeRequest(url: server, method: .options, headers: [:])
        let (_, response) = try await session.data(request: request)
        
        guard response.statusCode == 200 || response.statusCode == 204 else {
            throw TUSAPIError.couldNotFetchServerInfo
        }
        
        var supportedAlgorithms: [String] = []
        if let algorithms = response.allHeaderFields[caseInsensitive: "tus-checksum-algorithm"] as? String {
            supportedAlgorithms = algorithms.components(separatedBy: ",")
        }
        var supportedVersions: [String] = []
        if let tusVersions = response.allHeaderFields[caseInsensitive: "tus-version"] as? String {
            supportedVersions = tusVersions.components(separatedBy: ",")
        }
        var maxSize: Int?
        if let maxSizeStr = response.allHeaderFields[caseInsensitive: "tus-max-size"] as? String {
            maxSize = Int(maxSizeStr)
        }
        let version = response.allHeaderFields[caseInsensitive: "tus-resumable"] as? String ?? ""
            
        var extensions: [TUSProtocolExtension] = []
        if let tusExtension = response.allHeaderFields[caseInsensitive: "tus-extension"] as? String {
            extensions = tusExtension.components(separatedBy: ",").reduce(into: [TUSProtocolExtension]()) { partialResult, item in
                if let ext = TUSProtocolExtension(rawValue: item) {
                    partialResult.append(ext)
                }
            }
        }
        
        return TusServerInfo(version: version, maxSize: maxSize, extensions: extensions, supportedVersions: supportedVersions, supportedChecksumAlgorithms: supportedAlgorithms)
    }
    
    @discardableResult
    @available(*, deprecated, message: "Use async serverInfo(server:) instead")
    func serverInfo(server: URL, completion: @escaping @Sendable (Result<TusServerInfo, TUSAPIError>) -> Void) -> URLSessionDataTask {
        let request = makeRequest(url: server, method: .options, headers: [:])
        let task = session.dataTask(request: request) { result in
            processResult(completion: completion) {
                let (_, response) = try result.get()
                
                guard response.statusCode == 200 || response.statusCode == 204 else {
                    throw TUSAPIError.couldNotFetchServerInfo
                }
                    
                var supportedAlgorithms: [String] = []
                if let algorithms = response.allHeaderFields[caseInsensitive: "tus-checksum-algorithm"] as? String {
                    supportedAlgorithms = algorithms.components(separatedBy: ",")
                }
                var supportedVersions: [String] = []
                if let tusVersions = response.allHeaderFields[caseInsensitive: "tus-version"] as? String {
                    supportedVersions = tusVersions.components(separatedBy: ",")
                }
                var maxSize: Int?
                if let maxSizeStr = response.allHeaderFields[caseInsensitive: "tus-max-size"] as? String {
                    maxSize = Int(maxSizeStr)
                }
                let version = response.allHeaderFields[caseInsensitive: "tus-resumable"] as? String ?? ""
                    
                var extensions: [TUSProtocolExtension] = []
                if let tusExtension = response.allHeaderFields[caseInsensitive: "tus-extension"] as? String {
                    extensions = tusExtension.components(separatedBy: ",").reduce(into: [TUSProtocolExtension]()) { partialResult, item in
                        if let ext = TUSProtocolExtension(rawValue: item) {
                            partialResult.append(ext)
                        }
                    }
                }
                return TusServerInfo(version: version, maxSize: maxSize, extensions: extensions, supportedVersions: supportedVersions, supportedChecksumAlgorithms: supportedAlgorithms)
            }
        }
        task.resume()
        return task
    }
    
    /// Fetch the status of an upload if an upload is not finished (e.g. interrupted).
    /// By retrieving the status,  we know where to continue when we upload again.
    /// - Parameters:
    ///   - remoteDestination: A URL to retrieve the status from (received from the create call)
    ///   - headers: Request headers.
    func status(remoteDestination: URL, headers: [String: String]?) async throws -> Status {
        return try await withCheckedThrowingContinuation({ cont in
            self.status(remoteDestination: remoteDestination, headers: headers) { result in
                cont.resume(with: result)
            }
        })
    }
    
    /// Fetch the status of an upload if an upload is not finished (e.g. interrupted).
    /// By retrieving the status,  we know where to continue when we upload again.
    /// - Parameters:
    ///   - remoteDestination: A URL to retrieve the status from (received from the create call)
    ///   - headers: Request headers.
    ///   - completion: A completion giving us the `Status` of an upload.
    @discardableResult
    @available(*, deprecated, message: "Use async status method instead")
    func status(
        remoteDestination: URL,
        headers: [String: String]?,
        completion: @escaping @Sendable (Result<Status, TUSAPIError>) -> Void
    ) -> URLSessionDataTask {
        let request = makeRequest(url: remoteDestination, method: .head, headers: headers ?? [:])
        let identifier = UUID().uuidString
        
        let task = session.dataTask(with: request)
        task.taskDescription = identifier
        
        queue.sync {
            callbacks[identifier] = { result in
                processResult(completion: completion) {
                    let response =  try result.get()
                    
                    guard (200...299).contains(response.statusCode) else {
                        throw TUSAPIError.failedRequest(response)
                    }
                    
                    guard let lengthStr = response.allHeaderFields[caseInsensitive: "upload-Length"] as? String,
                          let length = Int(lengthStr),
                          let offsetStr = response.allHeaderFields[caseInsensitive: "upload-Offset"] as? String,
                          let offset = Int(offsetStr) else {
                        throw TUSAPIError.couldNotFetchStatus
                    }
                    return Status(length: length, offset: offset)
                }
            }
        }
        task.resume()
        return task
    }
    
    /// The create step of an upload. In this step, we tell the server we are about to upload data.
    /// The server returns a URL to upload to, we can use the `create` call for this.
    /// Use file metadata to enrich the information so the server knows what filetype something is.
    /// - Parameters:
    ///   - metaData: The file metadata.
    func create(metaData: UploadMetadata) async throws -> URL {
        return try await withCheckedThrowingContinuation({ cont in
            create(metaData: metaData) { result in
                cont.resume(with: result)
            }
        })
    }
    
    /// The create step of an upload. In this step, we tell the server we are about to upload data.
    /// The server returns a URL to upload to, we can use the `create` call for this.
    /// Use file metadata to enrich the information so the server knows what filetype something is.
    /// - Parameters:
    ///   - metaData: The file metadata.
    ///   - completion: Completes with a result that gives a URL to upload to.
    @discardableResult
    @available(*, deprecated, message: "Use async create method instead")
    func create(
        metaData: UploadMetadata,
        completion: @Sendable @escaping (Result<URL, TUSAPIError>) -> Void
    ) -> URLSessionDataTask {
        let request = makeCreateRequest(metaData: metaData)
        let identifier = UUID().uuidString
        let task = session.dataTask(with: request)
        task.taskDescription = identifier
        
        queue.sync {
            callbacks[identifier] =  { result in
                processResult(completion: completion) {
                    let response = try result.get()
                    
                    guard (200...299).contains(response.statusCode) else {
                        throw TUSAPIError.failedRequest(response)
                    }

                    guard let location = response.allHeaderFields[caseInsensitive: "location"] as? String,
                          let locationURL = URL(string: location, relativeTo: metaData.uploadURL) else {
                        throw TUSAPIError.couldNotRetrieveLocation
                    }

                    return locationURL
                }
            }
        }
        
        task.resume()
        return task
    }
    
    func makeCreateRequest(metaData: UploadMetadata) -> URLRequest {
        func makeUploadMetaHeader() -> [String: String] {
            var metaDataDict: [String: String] = [:]
            
            let fileName = metaData.filePath.lastPathComponent
            if !fileName.isEmpty && fileName != "/" { // A filename can be invalid, e.g. "/"
                metaDataDict["filename"] = fileName
            }
            
            if let mimeType = metaData.mimeType, !mimeType.isEmpty {
                metaDataDict["filetype"] = mimeType
            }
            
            if let context = metaData.context {
                metaDataDict = metaDataDict.merging(context) { _, new in new }
            }
            
            return metaDataDict
        }
       
        /// Turn dict into a comma separated base64 string
        func encode(_ dict: [String: String]) -> String? {
            guard !dict.isEmpty else { return nil }
            var str = ""
            for (key, value) in dict {
                let appendingStr: String
                if !str.isEmpty {
                    str += ","
                }
                appendingStr = "\(key) \(value.toBase64())"
                str = str + appendingStr
            }
            return str
        }
        
        var defaultHeaders = ["Upload-Length": String(metaData.size)]
        
        if let encodedMetadata = encode(makeUploadMetaHeader())  {
            defaultHeaders["Upload-Metadata"] = encodedMetadata
        }
        
        /// Attach all headers from customHeader property
        let headers = defaultHeaders.merging(metaData.customHeaders ?? [:]) { _, new in new }
        
        return makeRequest(url: metaData.uploadURL, method: .post, headers: headers)
    }
    
    /// Uploads data
    /// - Parameters:
    ///   - data: The data to upload. The data will not be chunked by this method! You must supply chunked data.
    ///   - range: The range of which to upload. Leave empty to upload the entire data in one piece.
    ///   - location: The location of where to upload to.
    func upload(data: Data, range: Range<Int>?, location: URL, metaData: UploadMetadata) async throws -> Int {
        return try await withCheckedThrowingContinuation({ cont in
            upload(data: data, range: range, location: location, metaData: metaData) { result in
                cont.resume(with: result)
            }
        })
    }
    
    /// Uploads data
    /// - Parameters:
    ///   - data: The data to upload. The data will not be chunked by this method! You must supply chunked data.
    ///   - range: The range of which to upload. Leave empty to upload the entire data in one piece.
    ///   - location: The location of where to upload to.
    ///   - completion: Completionhandler for when the upload is finished.
    @discardableResult
    @available(*, deprecated, message: "Use async upload method instead")
    func upload(
        data: Data,
        range: Range<Int>?,
        location: URL,
        metaData: UploadMetadata,
        completion: @escaping @Sendable (Result<Int, TUSAPIError>) -> Void
    ) -> URLSessionUploadTask {
        let offset: Int
        let length: Int
        if let range = range {
            offset = range.lowerBound
            length = range.upperBound
        } else {
            // Use entire range
            offset = 0
            length = data.count
        }
        
        let headers = [
            "Content-Type": "application/offset+octet-stream",
            "Upload-Offset": String(offset),
            "Content-Length": String(length)
        ]
        
        /// Attach all headers from customHeader property
        let headersWithCustom = headers.merging(metaData.customHeaders ?? [:]) { _, new in new }
        
        let request = makeRequest(url: location, method: .patch, headers: headersWithCustom)
        let task = session.uploadTask(with: request, from: data)
        task.taskDescription = metaData.id.uuidString
        
        queue.sync {
            callbacks[metaData.id.uuidString] = { result in
                processResult(completion: completion) {
                    let response = try result.get()
                    
                    guard (200...299).contains(response.statusCode) else {
                        throw TUSAPIError.failedRequest(response)
                    }
                    
                    guard let offsetStr = response.allHeaderFields[caseInsensitive: "upload-offset"] as? String,
                          let offset = Int(offsetStr) else {
                        throw TUSAPIError.couldNotRetrieveOffset
                    }
                    return offset
                }
            }
        }
        
        task.resume()
        
        return task
    }
    
    private func uploadTask(
        fromFile file: URL,
        offset: Int = 0,
        location: URL,
        metaData: UploadMetadata
    ) -> URLSessionUploadTask {
        let length: Int
        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: file.path) {
            if let bytes = fileAttributes[.size] as? Int64 {
                length = Int(bytes)
            } else {
                length = 0
            }
        } else {
            length = 0
        }
        
        let headers = [
            "Content-Type": "application/offset+octet-stream",
            "Upload-Offset": String(offset),
            "Content-Length": String(length)
        ]
        
        /// Attach all headers from customHeader property
        let headersWithCustom = headers.merging(metaData.customHeaders ?? [:]) { _, new in new }
        
        let request = makeRequest(url: location, method: .patch, headers: headersWithCustom)
        let task = session.uploadTask(with: request, fromFile: file)
        task.taskDescription = metaData.id.uuidString
        
        return task
    }
    
    func upload(fromFile file: URL, offset: Int = 0, location: URL, metaData: UploadMetadata) -> NetworkTask<Int, URLSessionUploadTask> {
        let urlSessionTask = uploadTask(
            fromFile: file, offset: offset, location: location,
            metaData: metaData
        )
        
        let task = NetworkTask<Int, URLSessionUploadTask>(
            urlsessionTask: urlSessionTask
        )
        
        upload(fromTask: urlSessionTask, metaData: metaData, completion: { result in
            Task {
                await task.sendResult(result.mapError({ $0 as any Error }))
            }
        })

        return task
    }
    
    private func upload(
        fromTask task: URLSessionUploadTask,
        metaData: UploadMetadata,
        completion: @escaping @Sendable (Result<Int, TUSAPIError>) -> Void
    ) {
        queue.sync {
            self.callbacks[metaData.id.uuidString] = { result in
                processResult(completion: completion) {
                    let response = try result.get()
                    guard let offsetStr = response.allHeaderFields[caseInsensitive: "upload-offset"] as? String,
                          let offset = Int(offsetStr) else {
                        throw TUSAPIError.couldNotRetrieveOffset
                    }
                    return offset
                }
            }
        }
        task.resume()
    }
    
    func registerCallback(
        _ completion: @escaping @Sendable (Result<Int, TUSAPIError>) -> Void,
        forMetadata metadata: UploadMetadata
    ) {
        queue.sync {
            self.callbacks[metadata.id.uuidString] = { result in
                processResult(completion: completion) {
                    let response = try result.get()
                    guard let offsetStr = response.allHeaderFields[caseInsensitive: "upload-offset"] as? String,
                          let offset = Int(offsetStr) else {
                        throw TUSAPIError.couldNotRetrieveOffset
                    }
                    return offset
                }
            }
        }
    }
    
    func registerBackgroundHandler(_ handler: @escaping @Sendable () -> Void) {
        backgroundHandler = handler
    }
    
    func checkTaskExists(for metadata: UploadMetadata) async -> Bool {
        return await withCheckedContinuation({ cont in
            session.getAllTasks(completionHandler: { tasks in
                let hasTask = tasks.contains(where: { task in
                    return task.taskDescription == metadata.id.uuidString
                })
                
                cont.resume(returning: hasTask)
            })
        })
        
    }
    
    /// A factory to make requests with sane defaults.
    /// - Parameters:
    ///   - url: The URL of the request.
    ///   - method: The HTTP method of a request.
    ///   - headers: The headers to add to the request.
    /// - Returns: A new URLRequest to use in any TUS API call.
    private func makeRequest(url: URL, method: HTTPMethod, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method.rawValue
        request.addValue("1.0.0", forHTTPHeaderField: "TUS-Resumable")
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        return request
    }
}

/// This helper function solves a couple problems:
/// - It removes boilerplate. E.g. always converting to a Result with TUSAPIError as its error type. No need to have multitple do catch or mapError flatMap cases in every return.
/// - It makes the callsite friendly, all you need to do is process your response normally, and throw if needed.
/// - It prevents littering the callsite with completion() calls all over the api responses.
/// - It also makes sure that completion is always called.
///
/// - Note: This method is synchronous and expects a throwing closure.
/// - Parameters:
///   - completion: The completion block to call after the processing is done.
///   - perform: The code to run. Is expected to return a value that will be passed to the completion block. This method may throw.
private func processResult<T>(completion: (Result<T, TUSAPIError>) -> Void, perform: () throws -> T) {
    do {
        let value = try perform()
        completion(Result.success(value))
    } catch let error as TUSAPIError {
        completion(Result.failure(error))
    } catch {
        completion(Result.failure(TUSAPIError.underlyingError(error)))
    }
}

extension Dictionary {
    
    /// Case insenstiive subscripting. Only for string keys.
    /// We downcast to string to support AnyHashable keys.
    subscript(caseInsensitive key: Key) -> Value? {
        guard let someKey = key as? String else {
            return nil
        }
        
        let lcKey = someKey.lowercased()
        for k in keys {
            if let aKey = k as? String {
                if lcKey == aKey.lowercased() {
                    return self[k]
                }
            }
        }
        return nil
    }
}

private extension TUSAPI {
    actor SessionDataDelegate: NSObject, URLSessionDataDelegate {
        private weak var api: TUSAPI?
        
        init(api: TUSAPI) {
            self.api = api
        }
        
        nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            Task {
                await api?.handleCompletionOfTask(task, withError: error)
            }
        }
        
        nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            Task {
                await api?.handleFinishOfBackgroundURLSessionEvents()
            }
        }
    }
    
    func handleCompletionOfTask(_ task: URLSessionTask, withError error: Error?) {
        queue.sync {
            guard let identifier = task.taskDescription else {
                return
            }
            
            defer {
                callbacks.removeValue(forKey: identifier)
            }
            
            guard let completion = callbacks[identifier] else {
                return
            }
            
            if let error = error {
                completion(.failure(TUSAPIError.underlyingError(error)))
                return
            }
            
            guard let response = task.response as? HTTPURLResponse else {
                completion(.failure(TUSAPIError.underlyingError(NetworkError.noHTTPURLResponse)))
                return
            }
            
            completion(.success(response))
        }
    }
    
    func setBackgroundHandler(_ newValue: (@Sendable () -> Void)?) {
        backgroundHandler = newValue
    }
    
    func handleFinishOfBackgroundURLSessionEvents() {
        if let backgroundHandler {
            Task { @MainActor in
                backgroundHandler()
                await setBackgroundHandler(nil)
            }
        }
    }
}

