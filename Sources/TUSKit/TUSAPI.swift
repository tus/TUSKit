//
//  TUSAPI.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation

/// The Uploader's responsibility is to perform work related to uploading.
/// This includes: Making requests, handling requests, handling errors.
final class TUSAPI {
    
    enum HTTPMethod: CustomStringConvertible {
        case post
        case get
        case patch
        case delete
        
        var description: String {
            switch self {
            
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
    
    init(uploadURL: URL) {
        self.uploadURL = uploadURL
    }
    
    func create(size: Int, completion: @escaping (URL) -> Void) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//            completion(URL(string: "www.tus.io")!)
//        }
//
//        return
        // TODO: Encode metadata
        // TODO Filename
        let headers: [String: String] =
            ["Upload-Extension": "creation",
             "Upload-Length": String(size)
            ]
        
        print(headers)
        
        let request = makeRequest(url: uploadURL, method: .post, headers: headers)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // TODO: Check error     
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // TODO: Call completion with error
                return
            }
            
            guard let location = httpResponse.allHeaderFields["Location"] as? String,
                  let locationURL = URL(string: location) else {
                // TODO: Call completion with error
                return
            }
            
            completion(locationURL)
        }
        task.resume()
    }
    
    /// Uploads data
    /// - Parameters:
    ///   - data: The data to upload. The data will not be chunked by this method! You must supply chunked data.
    ///   - range: The range of which the chunked data relates to. Helps determine the offset for the server.
    ///   - location: The location of where to upload to.
    ///   - completion: Completionhandler for when the upload is finished.
    
    static var uploads = 0
    func upload(data: Data, range: Range<Int>, location: URL, completion: @escaping () -> Void) {
        print("Going to upload \(data) for range \(range)")
        let offset = range.lowerBound
        let length = range.upperBound
        let headers = [
            "Content-Type": "application/offset+octet-stream",
            "Upload-Offset": String(offset),
            "Content-Length": String(length)
        ]

        let request = makeRequest(url: location, method: .patch, headers: headers)
        
        let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
            // TODO: Check error
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // TODO: Call completion with error
                return
            }
            completion()
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
