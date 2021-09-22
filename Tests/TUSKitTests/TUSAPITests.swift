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
    var mockNetwork: MockNetwork!
    
    override func setUp() {
        super.setUp()
        mockNetwork = MockNetwork()
        api = TUSAPI(uploadURL: URL(string: "www.tus.io")!, network: mockNetwork)
    }
    
    func testCreation() throws {
        let size = 300
        let expectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(), filePath: URL(string: "file://whatever/")!, size: size)
        api.create(metaData: metaData) { [unowned self] result in
            do {
                let url = try result.get()
                XCTAssertEqual(url, self.mockNetwork.uploadURL)
                expectation.fulfill()
            } catch {
                XCTFail("Expected to retrieve a URL for this test")
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(mockNetwork.receivedRequests.first?.allHTTPHeaderFields)
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
    
        api.upload(data: Data(), range: range, location: mockNetwork.uploadURL) { result in

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
