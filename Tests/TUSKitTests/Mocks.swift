//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 28/09/2021.
//

import Foundation
import TUSKit
import XCTest

/// TUSClientDelegate to support testing
final class TUSMockDelegate: TUSClientDelegate {
    
    var startedUploads = [UUID]()
    var finishedUploads = [(UUID, URL)]()
    var failedUploads = [(UUID, Error)]()
    var fileErrors = [TUSClientError]()
    var progressPerId = [UUID: Int]()
    var totalProgressReceived = [Int]()
    
    var receivedContexts = [[String: String]]()
    
    var activityCount: Int { finishedUploads.count + startedUploads.count + failedUploads.count + fileErrors.count }
    
    var finishUploadExpectation: XCTestExpectation?
    var startUploadExpectation: XCTestExpectation?
    var fileErrorExpectation: XCTestExpectation?
    var uploadFailedExpectation: XCTestExpectation?

    func didStartUpload(id: UUID, context: [String : String]?, client: TUSClient) {
        startedUploads.append(id)
        startUploadExpectation?.fulfill()
        if let context = context {
            receivedContexts.append(context)
        }
    }
    
    func didFinishUpload(id: UUID, url: URL, responseHeaders: [String: String]?, context: [String: String]?, client: TUSClient) {
        finishedUploads.append((id, url))
        finishUploadExpectation?.fulfill()
        if let context = context {
            receivedContexts.append(context)
        }
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        fileErrors.append(error)
        fileErrorExpectation?.fulfill()
    }
    
    func uploadFailed(id: UUID, error: Error, context: [String : String]?, client: TUSClient) {
        failedUploads.append((id, error))
        uploadFailedExpectation?.fulfill()
        if let context = context {
            receivedContexts.append(context)
        }
    }
    
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        totalProgressReceived.append(bytesUploaded)
    }
    
    func progressFor(id: UUID, context: [String : String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        progressPerId[id] = bytesUploaded
    }
}

    typealias Headers = [String: String]?

/// MockURLProtocol to support mocking the network
final class MockURLProtocol: URLProtocol {
    
    private static let queue = DispatchQueue(label: "com.tuskit.mockurlprotocol")
    
    struct Response {
        let status: Int
        let headers: [String: String]
        let data: Data?
    }
    
    static var responses = [String: (Headers) -> Response]()
    static var receivedRequests = [URLRequest]()
    
    static func reset() {
        queue.async {
            responses = [:]
            receivedRequests = []
        }
    }
    
    /// Define a response to be used for a method
    /// - Parameters:
    ///   - method: The http method (POST PATCH etc)
    ///   - makeResponse: A closure that returns a Response
    static func prepareResponse(for method: String, makeResponse: @escaping (Headers) -> Response) {
        queue.async {
            responses[method] = makeResponse
        }
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        // To check if this protocol can handle the given request.
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // Here you return the canonical version of the request but most of the time you pass the orignal one.
        return request
    }
    
    override func startLoading() {
        type(of: self).queue.async { [weak self] in
            // This is where you create the mock response as per your test case and send it to the URLProtocolClient.
            
            guard let self = self else { return }
            guard let client = self.client else { return }
            
            guard let method = self.request.httpMethod,
                    let preparedResponseClosure = type(of: self).responses[method] else {
                //            assertionFailure("No response found for \(String(describing: request.httpMethod)) prepared \(type(of: self).responses)")
                return
            }
            
            let preparedResponse = preparedResponseClosure(self.request.allHTTPHeaderFields)
            
            type(of: self).receivedRequests.append(self.request)
            
            let url = URL(string: "https://tusd.tusdemo.net/files")!
            let response = HTTPURLResponse(url: url, statusCode: preparedResponse.status, httpVersion: nil, headerFields: preparedResponse.headers)!
            
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            if let data = preparedResponse.data {
                client.urlProtocol(self, didLoad: data)
            }
            client.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }
}

