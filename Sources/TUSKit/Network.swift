//
//  Network.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//

import Foundation

enum NetworkError: Error {
    case noHTTPURLResponse
}

protocol NetworkTask {
    func resume()
}

/// Network represents the network we can make requests to. Can be a real URLSession or mock or something else.
/// The reason we mock this, is to avoid network calls in testing. We don't want to mock out TUSAPI, however, so we can properly test its functionality.
protocol Network {
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask
}

extension URLSessionTask: NetworkTask {}

extension URLSession: Network {
    
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        return dataTask(with: request, completionHandler: makeCompletion(completion: completion))
    }
    
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        
        return uploadTask(with: request, from: data, completionHandler: makeCompletion(completion: completion))
    }
    
}

/// Convenience method to turn a URLSessoin completion handler into a modern Result version. It also checks if response is a HTTPURLResponse
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
