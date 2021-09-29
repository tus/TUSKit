//
//  TUSAPI.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

/// The errors a TUSAPI can return
enum TUSAPIError: Error {
    case underlyingError(Error)
    case couldNotFetchStatus
    case couldNotRetrieveOffset
    case couldNotRetrieveLocation
}

/// The status of an upload.
struct Status {
    let length: Int
    let offset: Int
}

/// The Uploader's responsibility is to perform work related to uploading.
/// This includes: Making requests, handling requests, handling errors.
final class TUSAPI {
    enum HTTPMethod: CustomStringConvertible {
        case head
        case post
        case get
        case patch
        case delete
        
        var description: String {
            switch self {
            case .head:
                return "HEAD"
            case .post:
                return "POST"
            case .get:
                return "GET"
            case .patch:
                return "PATCH"
            case .delete:
                return "DELETE"
            }
        }
    }
    
    let session: URLSession
    let uploadURL: URL
    
    
    init(session: URLSession, uploadURL: URL) {
        self.session = session
        self.uploadURL = uploadURL
    }
    
    /// Fetch the status of an upload if an upload is not finished (e.g. interrupted).
    /// By retrieving the status,  we know where to continue when we upload again.
    /// - Parameters:
    ///   - remoteDestination: A URL to retrieve the status from (received from the create call)
    ///   - completion: A completion giving us the `Status` of an upload.
    @discardableResult
    func status(remoteDestination: URL, completion: @escaping (Result<Status, TUSAPIError>) -> Void) -> URLSessionDataTask {
        let request = makeRequest(url: remoteDestination, method: .head, headers: [:])
        let task = session.dataTask(request: request) { result in
            processResult(completion: completion) {
                let (_, response) =  try result.get()
                // Improvement: Make length optional
                guard let lengthStr = response.allHeaderFields["Upload-Length"] as? String,
                      let length = Int(lengthStr),
                      let offsetStr = response.allHeaderFields["Upload-Offset"] as? String,
                      let offset = Int(offsetStr) else {
                    throw TUSAPIError.couldNotFetchStatus
                }

                return Status(length: length, offset: offset)
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
    ///   - completion: Completes with a result that gives a URL to upload to.
    @discardableResult
    func create(metaData: UploadMetadata, completion: @escaping (Result<URL, TUSAPIError>) -> Void) -> URLSessionDataTask {
        let request = makeCreateRequest(metaData: metaData)
        let task = session.dataTask(request: request) { (result: Result<(Data?, HTTPURLResponse), Error>) in
            processResult(completion: completion) {
                let (_, response) = try result.get()

                guard let location = response.allHeaderFields["Location"] as? String,
                      let locationURL = URL(string: location) else {
                    throw TUSAPIError.couldNotRetrieveLocation
                }

                return locationURL
            }
        }
        
        task.resume()
        return task
    }
    
    func makeCreateRequest(metaData: UploadMetadata) -> URLRequest {
        /// Add extra mimetype parameters headers
        func makeEncodedMetaDataHeaders(name: String, mimeType: String?) -> [String: String] {
            switch (name.isEmpty, mimeType) {
            case (false, let type?):
                // Both fileName and fileType can be given. FileName goes first.
                return ["Upload-Metadata": "fileName \(name.toBase64()), filetype \(type.toBase64())"]
            case (true, let type?):
                // Only type is known.
                return ["Upload-Metadata": "filetype \(type.toBase64())"]
            case (false, nil):
                // Only name is known.
                return ["Upload-Metadata": "fileName \(name.toBase64())"]
            default:
                return [:]
            }
        }
        
        var headers = ["Upload-Extension": "creation",
                       "Upload-Length": String(metaData.size)]
        
        let fileName = metaData.filePath.lastPathComponent
        headers.merge(makeEncodedMetaDataHeaders(name: fileName, mimeType: metaData.mimeType)) { lhs, _ in lhs }
        if let customHeaders = metaData.customHeaders {
            headers.merge(customHeaders) { _, rhs in rhs }
        }

        return makeRequest(url: uploadURL, method: .post, headers: headers)
    }
    
    /// Uploads data
    /// - Parameters:
    ///   - data: The data to upload. The data will not be chunked by this method! You must supply chunked data.
    ///   - range: The range of which to upload. Leave empty to upload the entire data in one piece.
    ///   - location: The location of where to upload to.
    ///   - completion: Completionhandler for when the upload is finished.
    @discardableResult
    func upload(data: Data, range: Range<Int>?, location: URL, completion: @escaping (Result<Int, TUSAPIError>) -> Void) -> URLSessionUploadTask {
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
        
        let request = makeRequest(url: location, method: .patch, headers: headers)
        
        let task = session.uploadTask(request: request, data: data) { result in
            processResult(completion: completion) {
                let (_, response) = try result.get()
                guard let offsetStr = response.allHeaderFields["Upload-Offset"] as? String,
                      let offset = Int(offsetStr) else {
                    throw TUSAPIError.couldNotRetrieveOffset
                }
                return offset
            }
        }
        task.resume()
        
        return task
    }
    
    func makeUploadRequest(data: Data, location: URL) -> URLRequest {
        let offset: Int = 0
        let length: Int = data.count
        
        let headers = [
            "Content-Type": "application/offset+octet-stream",
            "Upload-Offset": String(offset),
            "Content-Length": String(length)
        ]

        return makeRequest(url: location, method: .patch, headers: headers)
        
    }
    
    /// A factory to make requests with sane defaults.
    /// - Parameters:
    ///   - url: The URL of the request.
    ///   - method: The HTTP method of a request.
    ///   - headers: The headers to add to the request.
    /// - Returns: A new URLRequest to use in any TUS API call.
    private func makeRequest(url: URL, method: HTTPMethod, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = String(describing: method)
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
