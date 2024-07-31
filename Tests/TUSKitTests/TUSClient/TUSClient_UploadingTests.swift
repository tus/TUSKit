import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_UploadingTests: XCTestCase {
    
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
        
        let docDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
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
    
    override func tearDown() {
        super.tearDown()
        clearDirectory(dir: fullStoragePath)
    }
    // MARK: - Adding files and data to upload
    
    func testUploadingNonExistentFileShouldThrow() async throws{
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("thisfiledoesntexist.jpg")
        do {
            try await client.uploadFileAt(filePath: fileURL)
            XCTFail("If a file doesn't exist, the client should throw a message right when an uploadTask is triggered")
        } catch {
            return
        }
    }
    
    func testUploadingExistingFile() async throws {
        do {
            try await client.uploadFileAt(filePath: Fixtures.makeFilePath())
        } catch {
            XCTFail("TUSClient should accept files that exist")
        }
    }
    
    func testUploadingValidData() async throws {
        do {
            try await client.upload(data: Fixtures.loadData())
        } catch {
            XCTFail("TUSClient should accept valid data")
        }
    }
    
    func testCantUploadEmptyFile() async throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let targetLocation = docDir.appendingPathComponent("myfile.txt")
        let data = Data()
        try data.write(to: targetLocation)
        
        do {
            try await client.uploadFileAt(filePath: targetLocation)
            XCTFail("Expected empty file to throw error")
        } catch {
            
        }
    }
    
    func testCantUploadEmptyData() async {
        let data = Data()
        do {
            try await client.upload(data: data)
            XCTFail("Expected empty data upload to fail")
        } catch {
            // ...
        }
    }
        // MARK: - Chunking
    
    func testSmallUploadsArentChunked() async throws {
        let ids = try await upload(data: Data("012345678".utf8))
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(2, MockURLProtocol.receivedRequests.count)
    }

    func testLargeUploadsWillBeChunked() async throws {
        // Above 500kb will be chunked
        let data = Fixtures.makeLargeData()
        
        XCTAssert(data.count > Fixtures.chunkSize, "prerequisite failed")
        let ids = try await upload(data: data)
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(3, MockURLProtocol.receivedRequests.count)
        let createRequests = MockURLProtocol.receivedRequests.filter { request in
            request.httpMethod == "POST"
        }
        XCTAssertEqual(1, createRequests.count, "The POST method (create) should have been called only once")
    }
    
    func testClientThrowsErrorsWhenReceivingWrongOffset() async throws {
        // Make sure that if a server gives a "wrong" offset, the uploader errors and doesn't end up in an infinite uploading loop.
        prepareNetworkForWrongOffset(data: data)
        try await upload(data: data, shouldSucceed: false)
        XCTAssertEqual(1, tusDelegate.failedUploads.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterRetry() async throws {
        // Make sure that chunking happens even after retries
        
        // We fail the client first, then restart and make it use a status call to continue
        // After which we make sure that calls get chunked properly.
        prepareNetworkForErronousResponses()
        let data = Fixtures.makeLargeData()
        let ids = try await upload(data: data, shouldSucceed: false)
        
        // Now that a large upload failed. Let's retry a succesful upload, fetch its status, and check the requests that have been created.
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()
        
        try await client.retry(id: ids[0])
        await waitForUploadsToFinish(1)
        
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        XCTAssert(statusReqests.isEmpty)
        XCTAssertEqual(1, creationRequests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterFetchingStatus() async throws {
        // First we make sure create succeeds. But uploading fails.
        // This means we can do a status call after. After which we measure if something will get chunked.
        prepareNetworkForFailingUploads()
        let data = Fixtures.makeLargeData()
        let ids = try await upload(data: data, shouldSucceed: false)
        
        // Now a file is created with a remote url. So next fetch means the client will perform a status call.
        // Let's retry uploading and make sure that status and 2 (not 1, because chunking) calls have been made.
        
        prepareNetworkForSuccesfulStatusCall(data: data)
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()

        try await client.retry(id: ids[0])
        await waitForUploadsToFinish(1)
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        XCTAssert(creationRequests.isEmpty)
        XCTAssertEqual(1, statusReqests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    // MARK: - Custom URLs
    
    func testUploadingToCustomURL() async throws {
        let url = URL(string: "www.custom-url")!
        try await client.upload(data: data, uploadURL: url)
        await waitForUploadsToFinish(1)
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(url, uploadRequests.first?.url)
    }
    
    // MARK: - Responses
    
    func testMakeSureClientCanHandleLowerCaseKeysInResponses() async throws {
        prepareNetworkForSuccesfulUploads(data: data, lowerCasedKeysInResponses: true)
        try await upload(data: data)
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
