//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 28/09/2021.
//

import Foundation
import TUSKit

/// TUSClientDelegate to support testing
final class TUSMockDelegate: TUSClientDelegate {
    var finishedUploads = [(UUID, URL)]()
    var startedUploads = [UUID]()
    var failedUploads = [(UUID, Error)]()
    var fileErrors = [TUSClientError]()
    
    func didFinishUpload(id: UUID, url: URL, client: TUSClient) {
        finishedUploads.append((id, url))
    }
    
    func didStartUpload(id: UUID, client: TUSClient) {
        startedUploads.append(id)
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        fileErrors.append(error)
    }
    
    func uploadFailed(id: UUID, error: Error, client: TUSClient) {
        failedUploads.append((id, error))
    }
}

/// MockURLProtocol to support mocking the network
final class MockURLProtocol: URLProtocol {
    
    static var receivedRequests = [URLRequest]()
    
    override class func canInit(with request: URLRequest) -> Bool {
        // To check if this protocol can handle the given request.
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // Here you return the canonical version of the request but most of the time you pass the orignal one.
        receivedRequests.append(request)
        return request
    }
    
    override func startLoading() {
        // This is where you create the mock response as per your test case and send it to the URLProtocolClient.
        guard let client = client else { return }
        let data = Data("I AM MOCKED DATA".utf8)
        let url = URL(string: "https://tusd.tusdemo.net/files")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data)
        client.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }
}

