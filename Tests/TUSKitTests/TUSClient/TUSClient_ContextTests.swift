import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_ContextTests: XCTestCase {
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!
    var mockTestID: String!
    
    private var receivedRequests: [URLRequest] {
        MockURLProtocol.receivedRequests(testID: mockTestID)
    }
    
    override func setUp() {
        super.setUp()
        
        relativeStoragePath = URL(string: UUID().uuidString)!
        mockTestID = UUID().uuidString
        
        MockURLProtocol.reset(testID: mockTestID)
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        data = Data("abcdef".utf8)
        
        client = makeClient(storagePath: relativeStoragePath,
                            sessionIdentifier: "TEST-\(mockTestID!)",
                            mockTestID: mockTestID)
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        do {
            try client.reset()
        } catch {
            XCTFail("Could not reset \(error)")
        }
        
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)
    }
    
    override func tearDown() {
        super.tearDown()
        client.stopAndCancelAll()
        MockURLProtocol.reset(testID: mockTestID)
        clearDirectory(dir: fullStoragePath)
    }
    
    // These tests are here to make sure you get the same context back that you passed to upload.
    
    func testContextIsReturnedAfterUploading() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        try client.upload(data: data, context: expectedContext)
        
        waitForUploadsToFinish()
        
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 2)),  "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsReturnedAfterUploadingMultipleFiles() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        try client.uploadMultiple(dataFiles: [data, data], context: expectedContext)
        
        waitForUploadsToFinish(2)
        
        // Two contexts for start, two for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsReturnedAfterUploadingMultipleFilePaths() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        let path = try Fixtures.makeFilePath()
        try client.uploadFiles(filePaths: [path, path], context: expectedContext)
        waitForUploadsToFinish(2)
        
        // Four contexts for start, four for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsGivenOnStart() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didStartExpectation = expectation(description: "Waiting for upload to start")
        didStartExpectation.expectedFulfillmentCount = files.count
        tusDelegate.startUploadExpectation = didStartExpectation
        try client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssert(tusDelegate.receivedContexts.contains(expectedContext))
    }
    
    func testContextIsGivenOnFailure() throws {
        prepareNetworkForFailingUploads(testID: mockTestID)
        
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didFailExpectation = expectation(description: "Waiting for upload to start")
        didFailExpectation.expectedFulfillmentCount = files.count
        tusDelegate.uploadFailedExpectation = didFailExpectation
        try client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        waitForExpectations(timeout: 5, handler: nil)
        // Expected the context 4 times. Two files on start, two files on error.
        XCTAssert(tusDelegate.receivedContexts.contains(expectedContext))
    }
    
    func testContextIsIncludedInUploadMetadata() throws {
        let key = "SomeKey"
        let value = "SomeValue"
        let context = [key: value]
        
        // Store file
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        func storeFileInDocumentsDir() throws -> URL {
            let targetLocation = documentDir.appendingPathComponent("myfile.txt")
            try data.write(to: targetLocation)
            return targetLocation
        }
        
        let location = try storeFileInDocumentsDir()
        
        let startedExpectation = expectation(description: "Waiting for uploads to start")
        tusDelegate.startUploadExpectation = startedExpectation
        
        try client.uploadFileAt(filePath: location, context: context)
        wait(for: [startedExpectation], timeout: 5)
        
        // Validate
        let createRequests = receivedRequests.filter { $0.httpMethod == "POST" }
        
        for request in createRequests {
            let headers = try XCTUnwrap(request.allHTTPHeaderFields)
            let metadata = try XCTUnwrap(headers["Upload-Metadata"])
                .components(separatedBy: CharacterSet([" ", ","]))
                .filter { !$0.isEmpty }
            
            XCTAssert(metadata.contains(key))
            XCTAssert(metadata.contains(value.toBase64()))
        }
    }
    
    // MARK: - Private helper methods for uploading

    private func waitForUploadsToFinish(_ amount: Int = 1) {
        let uploadExpectation = expectation(description: "Waiting for upload to finished")
        uploadExpectation.expectedFulfillmentCount = amount
        tusDelegate.finishUploadExpectation = uploadExpectation
        waitForExpectations(timeout: 6, handler: nil)
    }
    
    private func waitForUploadsToFail(_ amount: Int = 1) {
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = amount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        waitForExpectations(timeout: 6, handler: nil)
    }
    
    /// Upload data, a certain amount of times, and wait for it to be done.
    /// Can optionally prepare a failing upload too.
    @discardableResult
    private func upload(data: Data, amount: Int = 1, customHeaders: [String: String] = [:], shouldSucceed: Bool = true) throws -> [UUID] {
        let ids = try (0..<amount).map { _ -> UUID in
            return try client.upload(data: data, customHeaders: customHeaders)
        }
        
        if shouldSucceed {
            waitForUploadsToFinish(amount)
        } else {
            waitForUploadsToFail(amount)
        }

        return ids
    }
}
