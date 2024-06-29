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

// URLSession conveniences
extension URLSession {
    func data(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        return try await validate(data(for: request))
    }
    
    func upload(request: URLRequest, data: Data) async throws -> (Data, HTTPURLResponse) {
        return try await validate(upload(for: request, from: data))
    }
    
    func upload(request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
        return try await validate(upload(for: request, fromFile: file))
    }
    
    @available(*, deprecated, message: "use async data(request:) instead")
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: request, completionHandler: makeCompletion(completion: completion))
    }
    
    @available(*, deprecated, message: "use async upload(request:data:) instead")
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionUploadTask {
        return uploadTask(with: request, from: data, completionHandler: makeCompletion(completion: completion))
    }
    
    @available(*, deprecated, message: "use async upload(request:fromFile:) instead")
    func uploadTask(with request: URLRequest, fromFile file: URL, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> URLSessionUploadTask {
        return uploadTask(with: request, fromFile: file, completionHandler: makeCompletion(completion: completion))
    }
}

private func validate(_ tuple: (Data, URLResponse)) throws -> (Data, HTTPURLResponse) {
    guard let response = tuple.1 as? HTTPURLResponse else {
        throw NetworkError.noHTTPURLResponse
    }
    
    return (tuple.0, response)
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
