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
    var fileErrorsWithIds = [(UUID?, TUSClientError)]()
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
    
    func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient) {
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
    
    func fileError(id: UUID?, error: TUSClientError, client: TUSClient) {
        fileErrorsWithIds.append((id, error))
        fileError(error: error, client: client)
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
    static let testIDHeader = "X-Mock-Test-ID"
    
    private struct ResponseKey: Hashable {
        let method: String
        let testID: String?
    }
    
    private struct RequestRecord {
        let testID: String?
        let request: URLRequest
    }
    
    struct Response {
        let status: Int
        let headers: [String: String]
        let data: Data?
    }
    
    private static var responses = [ResponseKey: (Headers) -> Response]()
    private static var requestRecords = [RequestRecord]()
    
    static var receivedRequests: [URLRequest] {
        get {
            queue.sync {
                requestRecords.map(\.request)
            }
        }
        set {
            queue.sync {
                requestRecords = newValue.map { request in
                    RequestRecord(testID: request.value(forHTTPHeaderField: testIDHeader), request: request)
                }
            }
        }
    }
    
    static func receivedRequests(testID: String?) -> [URLRequest] {
        queue.sync {
            requestRecords
                .filter { $0.testID == testID }
                .map(\.request)
        }
    }
    
    static func reset(testID: String? = nil) {
        queue.sync {
            guard let testID else {
                responses = [:]
                requestRecords = []
                return
            }
            
            responses = responses.filter { $0.key.testID != testID }
            requestRecords.removeAll { $0.testID == testID }
        }
    }
    
    static func clearReceivedRequests(testID: String? = nil) {
        queue.sync {
            guard let testID else {
                requestRecords = []
                return
            }
            
            requestRecords.removeAll { $0.testID == testID }
        }
    }
    
    /// Define a response to be used for a method
    /// - Parameters:
    ///   - method: The http method (POST PATCH etc)
    ///   - makeResponse: A closure that returns a Response
    static func prepareResponse(for method: String, testID: String? = nil, makeResponse: @escaping (Headers) -> Response) {
        let key = ResponseKey(method: method, testID: testID)
        queue.sync {
            responses[key] = makeResponse
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
                  let preparedResponseClosure = {
                      let testID = self.request.value(forHTTPHeaderField: type(of: self).testIDHeader)
                      let key = ResponseKey(method: method, testID: testID)
                      let fallbackKey = ResponseKey(method: method, testID: nil)
                      return type(of: self).responses[key] ?? type(of: self).responses[fallbackKey]
                  }() else {
                //            assertionFailure("No response found for \(String(describing: request.httpMethod)) prepared \(type(of: self).responses)")
                return
            }
            
            let preparedResponse = preparedResponseClosure(self.request.allHTTPHeaderFields)
            
            type(of: self).requestRecords.append(
                RequestRecord(
                    testID: self.request.value(forHTTPHeaderField: type(of: self).testIDHeader),
                    request: self.request
                )
            )
            
            let responseURL = self.request.url ?? URL(string: "https://tusd.tusdemo.net/files")!
            let response = HTTPURLResponse(url: responseURL, statusCode: preparedResponse.status, httpVersion: nil, headerFields: preparedResponse.headers)!
            
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
