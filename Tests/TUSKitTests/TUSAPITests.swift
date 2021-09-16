//
//  TUSAPITests.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//

import Foundation

import XCTest
@testable import TUSKit

// For consistency we don't complete a call on the same runloop. Could produce unrealistic results. For more info read about Zalgo https://blog.izs.me/2013/08/designing-apis-for-asynchrony/

// Improvement: Don't run network code until resume is called.
final class MockNetworkTask: NetworkTask {
    func resume() {
        
    }
}

final class MockNetwork: Network {
    
    var receivedRequests = [URLRequest]()
    let uploadURL = URL(string: "https://tusd.tusdemo.net/files/3f934f6")!
    
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        receivedRequests.append(request)
        DispatchQueue.main.async {
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 201,
                                           httpVersion: nil,
                                           headerFields:
                                            ["Location": self.uploadURL.absoluteString])!
            completion(.success((nil, response)))
        }
        return MockNetworkTask()
    }
    
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        receivedRequests.append(request)
        DispatchQueue.main.async {
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 201,
                                           httpVersion: nil,
                                           headerFields: [:])!
            completion(.success((nil, response)))
        }
        
        return MockNetworkTask()
    }
}

final class TUSAPITests: XCTestCase {

    var api: TUSAPI!
    var mockNetwork: MockNetwork!
    
    override func setUp() {
        super.setUp()
        mockNetwork = MockNetwork()
        api = TUSAPI(uploadURL: URL(string: "www.tus.io")!, network: mockNetwork)
    }
    
    func testCreation() throws {
        let size = 300
        let expectation = expectation(description: "Call api.create()")
        api.create(size: size) { [unowned self] url in
            XCTAssertEqual(url, self.mockNetwork.uploadURL)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(mockNetwork.receivedRequests.first?.allHTTPHeaderFields)
        let expectedHeaders: [String: String] =
            [
                "TUS-Resumable": "1.0.0",
                "Upload-Extension": "creation",
                "Upload-Length": String(size)
            ]
        
        XCTAssertEqual(headerFields, expectedHeaders)
    }
    
    func testUpload() throws {
        let offset = 2
        let length = 10
        let range = offset..<length
        let expectation = expectation(description: "Call api.upload()")
        api.upload(data: Data(), range: range, location: mockNetwork.uploadURL) {
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(mockNetwork.receivedRequests.first?.allHTTPHeaderFields)
        let expectedHeaders: [String: String] =
            [
                "TUS-Resumable": "1.0.0",
                "Content-Type": "application/offset+octet-stream",
                "Upload-Offset": String(offset),
                "Content-Length": String(length)
            ]
        
        XCTAssertEqual(headerFields, expectedHeaders)
    }
}
