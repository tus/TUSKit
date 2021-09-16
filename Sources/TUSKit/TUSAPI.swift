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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion(URL(string: "www.tus.io")!)
        }
        
        return
        // TODO: Encode metadata
//        "Upload-Metadata": [
//           "filename": "TESTFILENAME"]]

        // TODO Filename
        let headers: [String: String] =
            ["Upload-Extension": "creation",
             "Upload-Length": String(size)
            ]
                
        print(headers)
        
        let request = makeRequest(method: .post, headers: headers)

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
    
    func upload(data: Data, range: Range<Int>, completion: @escaping () -> Void) {
        print("Going to upload \(data) for range \(range)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion()
        }
    }

    private func makeRequest(method: HTTPMethod, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: uploadURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.httpMethod = method.description
        request.addValue("1.0.0", forHTTPHeaderField: "TUS-Resumable")
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        return request
    }
}
