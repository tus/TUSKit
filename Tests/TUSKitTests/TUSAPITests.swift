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
		api = TUSAPI(session: session, supportedExtensions: .all)
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.receivedRequests = []
    }
    
    func testStatus() throws {
        let length = 3000
        let offset = 20
        MockURLProtocol.prepareResponse(for: "HEAD") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Upload-Length": String(length), "Upload-Offset": String(offset)], data: nil)
        }
        
        let statusExpectation = expectation(description: "Call api.status()")
        let remoteFileURL = URL(string: "https://tus.io/myfile")!
        
        let metaData = UploadMetadata(id: UUID(),
                                              filePath: URL(string: "file://whatever/abc")!,
                                              uploadURL: URL(string: "io.tus")!,
                                              size: length)
        
        api.status(remoteDestination: remoteFileURL, headers:  metaData.customHeaders, completion: { result in
            do {
                let values = try result.get()
                XCTAssertEqual(length, values.length)
                XCTAssertEqual(offset, values.offset)
                statusExpectation.fulfill()
            } catch {
                XCTFail("Expected this call to succeed")
            }
        })
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCreationWithAbsolutePath() throws {
        let remoteFileURL = URL(string: "https://tus.io/myfile")!
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": remoteFileURL.absoluteString], data: nil)
        }
        
        let size = 300
        let creationExpectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: URL(string: "https://io.tus")!,
                                      size: size)
        api.create(metaData: metaData) { result in
            do {
                let url = try result.get()
                XCTAssertEqual(url, remoteFileURL)
                creationExpectation.fulfill()
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
                "Upload-Metadata": "filename \(expectedFileName)"
            ]
        
        XCTAssertEqual(expectedHeaders, headerFields)
    }
    
    func testCreationWithRelativePath() throws {
        let uploadURL = URL(string: "https://tus.example.org/files")!
        let relativePath = "files/24e533e02ec3bc40c387f1a0e460e216"
        let expectedURL = URL(string: "https://tus.example.org/files/24e533e02ec3bc40c387f1a0e460e216")!
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": relativePath], data: nil)
        }
        
        let size = 300
        let creationExpectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: uploadURL,
                                      size: size)
        api.create(metaData: metaData) { result in
            do {
                let url = try result.get()
                XCTAssertEqual(url.absoluteURL, expectedURL)
                creationExpectation.fulfill()
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
                "Upload-Metadata": "filename \(expectedFileName)"
            ]
        
        XCTAssertEqual(expectedHeaders, headerFields)
    }
    
    func testUpload() throws {
        let data = Data("Hello how are you".utf8)
        MockURLProtocol.prepareResponse(for: "PATCH") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(data.count)], data: nil)
        }
        
        let offset = 2
        let length = data.count
        let range = offset..<data.count
        let uploadExpectation = expectation(description: "Call api.upload()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: URL(string: "io.tus")!,
                                      size: length)
    
        let task = api.upload(data: Data(), range: range, location: uploadURL, metaData: metaData) { _ in
            uploadExpectation.fulfill()
        }
        XCTAssertEqual(task.originalRequest?.url, uploadURL)
        
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
    
    func testUploadWithRelativePath() throws {
        let data = Data("Hello how are you".utf8)
        let baseURL = URL(string: "https://tus.example.org/files")!
        let relativePath = "files/24e533e02ec3bc40c387f1a0e460e216"
        let uploadURL = URL(string: relativePath, relativeTo: baseURL)!
        let expectedURL = URL(string: "https://tus.example.org/files/24e533e02ec3bc40c387f1a0e460e216")!
        MockURLProtocol.prepareResponse(for: "PATCH") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(data.count)], data: nil)
        }
        
        let offset = 2
        let length = data.count
        let range = offset..<data.count
        let uploadExpectation = expectation(description: "Call api.upload()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: URL(string: "io.tus")!,
                                      size: length)
    
        let task = api.upload(data: Data(), range: range, location: uploadURL, metaData: metaData) { _ in
            uploadExpectation.fulfill()
        }
        XCTAssertEqual(task.originalRequest?.url, expectedURL)
        
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
