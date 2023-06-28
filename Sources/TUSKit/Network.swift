//
//  Network.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//
//
import Foundation

enum NetworkError: Error {
    case noHTTPURLResponse
}

// Result support for URLSession
extension URLSession {
    
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: request, completionHandler: makeCompletion(completion: completion))
    }
    
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionUploadTask {
        return uploadTask(with: request, from: data, completionHandler: makeCompletion(completion: completion))
    }
    
    func uploadTask(with request: URLRequest, fromFile file: URL, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionUploadTask {
        return uploadTask(with: request, fromFile: file, completionHandler: makeCompletion(completion: completion))
    }
}

/// Convenience method to turn a URLSession completion handler into a modern Result version. It also checks if response is a HTTPURLResponse
/// - Parameter completion: A completionhandler to call
/// - Returns: A new function that you can pass to URLSession's dataTask
private func makeCompletion(completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> (Data?, URLResponse?, Error?) -> Void {
    return { data, response, error in
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(NetworkError.noHTTPURLResponse))
            return
        }

        completion(.success((data, httpResponse)))
    }
}
