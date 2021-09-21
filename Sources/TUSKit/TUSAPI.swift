//
//  TUSAPI.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

enum TUSAPIError: Error {
    case underlyingError(Error)
    case couldNotFetchStatus
    case couldNotRetrieveOffset
    case couldNotRetrieveLocation
}

struct Status {
    let length: Int
    let offset: Int
}

/// The Uploader's responsibility is to perform work related to uploading.
/// This includes: Making requests, handling requests, handling errors.
final class TUSAPI {
    
    let network: Network
    
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
    
    let uploadURL: URL
    
    init(uploadURL: URL, network: Network) {
        self.network = network
        self.uploadURL = uploadURL
    }
    
    
    func status(remoteDestination: URL, completion: @escaping (Result<Status, TUSAPIError>) -> Void) {
        let request = makeRequest(url: remoteDestination, method: .head, headers: [:])
        let task = network.dataTask(request: request) { result in
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
    }
    
    func create(metaData: UploadMetadata, completion: @escaping (Result<URL, TUSAPIError>) -> Void) {
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

        let request = makeRequest(url: uploadURL, method: .post, headers: headers)
        let task = network.dataTask(request: request) { (result: Result<(Data?, HTTPURLResponse), Error>) in
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
    }
    
    /// Uploads data
    /// - Parameters:
    ///   - data: The data to upload. The data will not be chunked by this method! You must supply chunked data.
    ///   - range: The range of which to upload. Leave empty to upload the entire data in one piece.
    ///   - location: The location of where to upload to.
    ///   - completion: Completionhandler for when the upload is finished.
    
    func upload(data: Data, range: Range<Int>?, location: URL, completion: @escaping (Result<Int, TUSAPIError>) -> Void) {
        // TODO: Logger
        print("Going to upload \(data) for range \(String(describing: range))")
        let headers: [String: String]
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
        
        headers = [
            "Content-Type": "application/offset+octet-stream",
            "Upload-Offset": String(offset),
            "Content-Length": String(length)
        ]

        let request = makeRequest(url: location, method: .patch, headers: headers)
        
        let task = network.uploadTask(request: request, data: data) { result in
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
    }
    
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

private extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

}

/// Little helper function that will transform all errors to a TUSAPIError.
///
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
