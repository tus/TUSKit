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
    var finishedUploads = [(UUID, URL)]()
    var startedUploads = [UUID]()
    var failedUploads = [(UUID, Error)]()
    var fileErrors = [TUSClientError]()
    
    var finishUploadExpectation: XCTestExpectation?
    var startUploadExpectation: XCTestExpectation?
    var fileErrorExpectation: XCTestExpectation?
    var uploadFailedExpectation: XCTestExpectation?
    
    func didFinishUpload(id: UUID, url: URL, client: TUSClient) {
        finishedUploads.append((id, url))
        
        finishUploadExpectation?.fulfill()
    }
    
    func didStartUpload(id: UUID, client: TUSClient) {
        startedUploads.append(id)
        startUploadExpectation?.fulfill()
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        fileErrors.append(error)
        fileErrorExpectation?.fulfill()
    }
    
    func uploadFailed(id: UUID, error: Error, client: TUSClient) {
        failedUploads.append((id, error))
        uploadFailedExpectation?.fulfill()
    }
}

/// MockURLProtocol to support mocking the network
final class MockURLProtocol: URLProtocol {
    
    struct Response {
        let status: Int
        let headers: [String: String]
        let data: Data?
    }
    
    static var responses = [String: Response]()
    static var currentResponse: Response?
    static var receivedRequests = [URLRequest]()
    
    /// Define a response to be used for a method
    /// - Parameters:
    ///   - method: The http method (POST PATCH etc)
    ///   - makeResponse: A closure that returns a Response
    static func prepareResponse(for method: String, makeResponse: () -> Response) {
        responses[method] = makeResponse()
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        // To check if this protocol can handle the given request.
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // Here you return the canonical version of the request but most of the time you pass the orignal one.
        if let method = request.httpMethod {
            currentResponse = responses[method]
        } else {
            assertionFailure("No http method found for request")
        }
        receivedRequests.append(request)
        return request
    }
    
    override func startLoading() {
        // This is where you create the mock response as per your test case and send it to the URLProtocolClient.
        guard let client = client else { return }
        
        DispatchQueue.main.async { // Next runloop to mimic network
            guard let preparedResponse = type(of: self).currentResponse else {
                assertionFailure("No response found")
                return
            }
            
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

