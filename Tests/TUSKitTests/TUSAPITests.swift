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
    var mockTestID: String!
    
    override func setUp() {
        super.setUp()
        
        mockTestID = UUID().uuidString
        MockURLProtocol.reset(testID: mockTestID)
        
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        if let mockTestID {
            configuration.httpAdditionalHeaders = [MockURLProtocol.testIDHeader: mockTestID]
        }
        uploadURL = URL(string: "www.tus.io")!
        api = TUSAPI(sessionConfiguration: configuration)
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset(testID: mockTestID)
    }
    
    func testStatus() throws {
        let length = 3000
        let offset = 20
        MockURLProtocol.prepareResponse(for: "HEAD", testID: mockTestID) { _ in
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
        MockURLProtocol.prepareResponse(for: "POST", testID: mockTestID) { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": remoteFileURL.absoluteString], data: nil)
        }
        
        let size = 300
        let creationExpectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: URL(string: "https://io.tus")!,
                                      size: size)
        api.create(metaData: metaData, customHeaders: metaData.customHeaders ?? [:]) { result in
            do {
                let url = try result.get()
                XCTAssertEqual(url, remoteFileURL)
                creationExpectation.fulfill()
            } catch {
                XCTFail("Expected to retrieve a URL for this test")
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests(testID: mockTestID).first?.allHTTPHeaderFields)
        let expectedFileName = metaData.filePath.lastPathComponent.toBase64()
        XCTAssertEqual("1.0.0", headerFields["TUS-Resumable"])
        XCTAssertEqual(String(size), headerFields["Upload-Length"])
        XCTAssertEqual("filename \(expectedFileName)", headerFields["Upload-Metadata"])
    }
    
    func testCreationWithRelativePath() throws {
        let uploadURL = URL(string: "https://tus.example.org/files")!
        let relativePath = "files/24e533e02ec3bc40c387f1a0e460e216"
        let expectedURL = URL(string: "https://tus.example.org/files/24e533e02ec3bc40c387f1a0e460e216")!
        MockURLProtocol.prepareResponse(for: "POST", testID: mockTestID) { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": relativePath], data: nil)
        }
        
        let size = 300
        let creationExpectation = expectation(description: "Call api.create()")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: URL(string: "file://whatever/abc")!,
                                      uploadURL: uploadURL,
                                      size: size)
        api.create(metaData: metaData, customHeaders: metaData.customHeaders ?? [:]) { result in
            do {
                let url = try result.get()
                XCTAssertEqual(url.absoluteURL, expectedURL)
                creationExpectation.fulfill()
            } catch {
                XCTFail("Expected to retrieve a URL for this test")
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests(testID: mockTestID).first?.allHTTPHeaderFields)
        let expectedFileName = metaData.filePath.lastPathComponent.toBase64()
        XCTAssertEqual("1.0.0", headerFields["TUS-Resumable"])
        XCTAssertEqual(String(size), headerFields["Upload-Length"])
        XCTAssertEqual("filename \(expectedFileName)", headerFields["Upload-Metadata"])
    }
    
    func testUpload() throws {
        let data = Data("Hello how are you".utf8)
        MockURLProtocol.prepareResponse(for: "PATCH", testID: mockTestID) { _ in
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
    
        let task = api.upload(data: Data(), range: range, location: uploadURL, metaData: metaData, customHeaders: metaData.customHeaders ?? [:]) { _ in
            uploadExpectation.fulfill()
        }
        XCTAssertEqual(task.originalRequest?.url, uploadURL)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests(testID: mockTestID).first?.allHTTPHeaderFields)
        XCTAssertEqual("1.0.0", headerFields["TUS-Resumable"])
        XCTAssertEqual("application/offset+octet-stream", headerFields["Content-Type"])
        XCTAssertEqual(String(offset), headerFields["Upload-Offset"])
        XCTAssertEqual(String(length), headerFields["Content-Length"])
    }

    func testUploadFromFileReportsFailedRequestWhenPatchResponseHasNoOffset() throws {
        let data = Data("Hello how are you".utf8)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let responseData = Data("Upload offset is stale".utf8)
        MockURLProtocol.prepareResponse(for: "PATCH", testID: mockTestID) { _ in
            MockURLProtocol.Response(status: 409, headers: [:], data: responseData)
        }

        let uploadExpectation = expectation(description: "Call api.upload(fromFile:)")
        let metaData = UploadMetadata(id: UUID(),
                                      filePath: fileURL,
                                      uploadURL: URL(string: "io.tus")!,
                                      size: data.count)

        api.upload(fromFile: fileURL, offset: data.count, location: uploadURL, metaData: metaData, customHeaders: metaData.customHeaders ?? [:]) { result in
            switch result {
            case .success:
                XCTFail("Expected failed PATCH response to be reported")
            case .failure(.failedRequest(let response, let data)):
                XCTAssertEqual(response.statusCode, 409)
                XCTAssertEqual(data, responseData)
            case .failure(let error):
                XCTFail("Expected failedRequest, got \(error)")
            }
            uploadExpectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    // MARK: - Progress delegate

    func testProgressDelegateFiredViaHandleProgressForTask() {
        let id = UUID()
        var receivedID: UUID?
        var receivedSent: Int64 = 0
        var receivedExpected: Int64 = 0
        let delegateExpectation = expectation(description: "progress delegate fires")

        let mockDelegate = MockProgressDelegate { firedID, sent, expected in
            receivedID = firedID
            receivedSent = sent
            receivedExpected = expected
            delegateExpectation.fulfill()
        }
        api.progressDelegate = mockDelegate

        let task = MockURLSessionTask(taskDescription: id.uuidString)
        api.handleProgressForTask(task, totalBytesSent: 512, totalBytesExpectedToSend: 1024)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedID, id)
        XCTAssertEqual(receivedSent, 512)
        XCTAssertEqual(receivedExpected, 1024)
    }

    func testCompatibilityProgressObservationRoutesProgressWhenDelegateCallbacksAreUnavailable() {
        let id = UUID()
        var receivedID: UUID?
        var receivedSent: Int64 = 0
        var receivedExpected: Int64 = 0
        let delegateExpectation = expectation(description: "progress delegate fires")

        let mockDelegate = MockProgressDelegate { firedID, sent, expected in
            receivedID = firedID
            receivedSent = sent
            receivedExpected = expected
            delegateExpectation.fulfill()
        }
        api.progressDelegate = mockDelegate

        let task = MockURLSessionTask(taskDescription: id.uuidString)
        api.observeProgressForCompatibility(task: task, totalBytesExpectedToSend: 1024)

        task.progress.totalUnitCount = 1024
        task.progress.completedUnitCount = 512

        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedID, id)
        XCTAssertEqual(receivedSent, 512)
        XCTAssertEqual(receivedExpected, 1024)
    }

    func testProgressDelegateNotCalledForNilTaskDescription() {
        var callCount = 0
        let mockDelegate = MockProgressDelegate { _, _, _ in callCount += 1 }
        api.progressDelegate = mockDelegate

        let task = MockURLSessionTask(taskDescription: nil)
        api.handleProgressForTask(task, totalBytesSent: 512, totalBytesExpectedToSend: 1024)

        let flush = expectation(description: "flush")
        DispatchQueue.main.async { flush.fulfill() }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(callCount, 0)
    }

    func testProgressDelegateNotCalledForInvalidUUIDTaskDescription() {
        var callCount = 0
        let mockDelegate = MockProgressDelegate { _, _, _ in callCount += 1 }
        api.progressDelegate = mockDelegate

        let task = MockURLSessionTask(taskDescription: "not-a-uuid")
        api.handleProgressForTask(task, totalBytesSent: 512, totalBytesExpectedToSend: 1024)

        let flush = expectation(description: "flush")
        DispatchQueue.main.async { flush.fulfill() }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(callCount, 0)
    }

    func testUploadWithRelativePath() throws {
        let data = Data("Hello how are you".utf8)
        let baseURL = URL(string: "https://tus.example.org/files")!
        let relativePath = "files/24e533e02ec3bc40c387f1a0e460e216"
        let uploadURL = URL(string: relativePath, relativeTo: baseURL)!
        let expectedURL = URL(string: "https://tus.example.org/files/24e533e02ec3bc40c387f1a0e460e216")!
        MockURLProtocol.prepareResponse(for: "PATCH", testID: mockTestID) { _ in
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
    
        let task = api.upload(data: Data(), range: range, location: uploadURL, metaData: metaData, customHeaders: metaData.customHeaders ?? [:]) { _ in
            uploadExpectation.fulfill()
        }
        XCTAssertEqual(task.originalRequest?.url, expectedURL)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let headerFields = try XCTUnwrap(MockURLProtocol.receivedRequests(testID: mockTestID).first?.allHTTPHeaderFields)
        XCTAssertEqual("1.0.0", headerFields["TUS-Resumable"])
        XCTAssertEqual("application/offset+octet-stream", headerFields["Content-Type"])
        XCTAssertEqual(String(offset), headerFields["Upload-Offset"])
        XCTAssertEqual(String(length), headerFields["Content-Length"])
    }

}

// MARK: - Helpers

private final class MockProgressDelegate: ProgressDelegate {
    private let handler: (UUID, Int64, Int64) -> Void

    init(_ handler: @escaping (UUID, Int64, Int64) -> Void) {
        self.handler = handler
    }

    func progressUpdated(forID id: UUID, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        handler(id, totalBytesSent, totalBytesExpectedToSend)
    }
}
