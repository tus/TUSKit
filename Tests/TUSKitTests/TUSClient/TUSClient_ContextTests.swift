import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_ContextTests: XCTestCase {
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        
        relativeStoragePath = URL(string: "TUSTEST")!
        
        MockURLProtocol.reset()
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        data = Data("abcdef".utf8)
        
        client = makeClient(storagePath: relativeStoragePath)
        tusDelegate = TUSMockDelegate()
        await client.setDelegate(tusDelegate)
        do {
            try await client.reset()
        } catch {
            XCTFail("Could not reset \(error)")
        }
        
        prepareNetworkForSuccesfulUploads(data: data)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        await client.stopAndCancelAll()
        clearDirectory(dir: fullStoragePath)
    }
    
    // These tests are here to make sure you get the same context back that you passed to upload.
    
    func testContextIsReturnedAfterUploading() async throws {
        let expectedContext = ["I am a key" : "I am a value"]
        try await client.upload(data: data, context: expectedContext)
        
        await waitForUploadsToFinish()
        
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 2)),  "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsReturnedAfterUploadingMultipleFiles() async throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        try await client.uploadMultiple(dataFiles: [data, data], context: expectedContext)
        
        await waitForUploadsToFinish(2)
        
        // Two contexts for start, two for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsReturnedAfterUploadingMultipleFilePaths() async throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        let path = try Fixtures.makeFilePath()
        try await client.uploadFiles(filePaths: [path, path], context: expectedContext)
        await waitForUploadsToFinish(2)
        
        // Four contexts for start, four for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsGivenOnStart() async throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didStartExpectation = expectation(description: "Waiting for upload to start")
        didStartExpectation.expectedFulfillmentCount = files.count
        tusDelegate.startUploadExpectation = didStartExpectation
        try await client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        await fulfillment(of: [tusDelegate.startUploadExpectation!])
        XCTAssert(tusDelegate.receivedContexts.contains(expectedContext))
    }
    
    func testContextIsGivenOnFailure() async throws {
        prepareNetworkForFailingUploads()
        
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didFailExpectation = expectation(description: "Waiting for upload to start")
        didFailExpectation.expectedFulfillmentCount = files.count
        tusDelegate.uploadFailedExpectation = didFailExpectation
        try await client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        await fulfillment(of: [tusDelegate.uploadFailedExpectation!])
        // Expected the context 4 times. Two files on start, two files on error.
        XCTAssert(tusDelegate.receivedContexts.contains(expectedContext))
    }
    
    func testContextIsIncludedInUploadMetadata() async throws {
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
        
        try await client.uploadFileAt(filePath: location, context: context)
        await fulfillment(of: [startedExpectation], timeout: 5)
        
        // Validate
        let createRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        
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

    private func waitForUploadsToFinish(_ amount: Int = 1) async {
        let uploadExpectation = expectation(description: "Waiting for upload to finished")
        uploadExpectation.expectedFulfillmentCount = amount
        tusDelegate.finishUploadExpectation = uploadExpectation
        await fulfillment(of: [uploadExpectation], timeout: 6)
    }
    
    private func waitForUploadsToFail(_ amount: Int = 1) async {
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = amount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        await fulfillment(of: [uploadFailedExpectation], timeout: 6)
    }
    
    /// Upload data, a certain amount of times, and wait for it to be done.
    /// Can optionally prepare a failing upload too.
    @discardableResult
    private func upload(data: Data, amount: Int = 1, customHeaders: [String: String] = [:], shouldSucceed: Bool = true) async throws -> [UUID] {
        let ids = try await withThrowingTaskGroup(of: UUID.self) { group in
            for _ in 0..<amount {
                group.addTask {
                    try await self.client.upload(data: data, customHeaders: customHeaders)
                }
            }
            
            var ids = [UUID]()
            for try await id in group {
                ids.append(id)
            }
            return ids
        }
        
        if shouldSucceed {
            await waitForUploadsToFinish(amount)
        } else {
            await waitForUploadsToFail(amount)
        }

        return ids
    }
}
