//
//  TUSAPITests.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 16/09/2021.
//

import Foundation

import XCTest
@testable import TUSKit

final class TUSAPITests: XCTestCase {

    var api: TUSAPI!
    var uploadURL: URL!
    
    override func setUp() {
        super.setUp()
        
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession.init(configuration: configuration)
        uploadURL = URL(string: "www.tus.io")!
        api = TUSAPI(session: session, uploadURL: uploadURL)
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.receivedRequests = []
    }
    
    func testCreation() throws {
        // TODO: Set proper response in mock 
        let size = 300
        let expectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(), filePath: URL(string: "file://whatever/")!, size: size)
        api.create(metaData: metaData) { [unowned self] result in
            do {
                let url = try result.get()
                XCTAssertEqual(url, self.uploadURL)
                expectation.fulfill()
            } catch {
                XCTFail("Expected to retrieve a URL for this test")
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests.first?.allHTTPHeaderFields)
        let expectedFileName = metaData.filePath.lastPathComponent.toBase64()
        let expectedHeaders: [String: String] =
            [
                "TUS-Resumable": "1.0.0",
                "Upload-Extension": "creation",
                "Upload-Length": String(size),
                "Upload-Metadata": "fileName \(expectedFileName)"
            ]
        
        
        XCTAssertEqual(headerFields, expectedHeaders)
    }
    
    func testUpload() throws {
        let offset = 2
        let length = 10
        let range = offset..<length
        let expectation = expectation(description: "Call api.upload()")
    
        api.upload(data: Data(), range: range, location: uploadURL) { result in

            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests.first?.allHTTPHeaderFields)
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
