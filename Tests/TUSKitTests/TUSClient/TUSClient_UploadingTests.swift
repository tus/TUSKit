import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_UploadingTests: XCTestCase {
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!
    
    override func setUp() {
        super.setUp()
        
        relativeStoragePath = URL(string: "TUSTEST")!
        
        MockURLProtocol.reset()
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        data = Data("abcdef".utf8)
        
        client = makeClient(storagePath: relativeStoragePath)
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        do {
            try client.reset()
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
    
    func testUploadingNonExistentFileShouldThrow() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("thisfiledoesntexist.jpg")
        XCTAssertThrowsError(try client.uploadFileAt(filePath: fileURL), "If a file doesn't exist, the client should throw a message right when an uploadTask is triggered")
    }
    
    func testUploadingExistingFile() {
        try XCTAssertNoThrow(client.uploadFileAt(filePath: Fixtures.makeFilePath()), "TUSClient should accept files that exist")
    }
    
    func testUploadingValidData() throws {
        XCTAssertNoThrow(try client.upload(data: Fixtures.loadData()))
    }
    
    func testCantUploadEmptyFile() throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let targetLocation = docDir.appendingPathComponent("myfile.txt")
        let data = Data()
        try data.write(to: targetLocation)
        
        try XCTAssertThrowsError(client.uploadFileAt(filePath: targetLocation))
    }
    
    func testCantUploadEmptyData() {
        let data = Data()
        try XCTAssertThrowsError(client.upload(data: data))
    }
        // MARK: - Chunking
    
    func testSmallUploadsArentChunked() throws {
        let ids = try upload(data: Data("012345678".utf8))
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(2, MockURLProtocol.receivedRequests.count)
    }

    func testLargeUploadsWillBeChunked() throws {
        // Above 500kb will be chunked
        let data = Fixtures.makeLargeData()
        
        XCTAssert(data.count > Fixtures.chunkSize, "prerequisite failed")
        let ids = try upload(data: data)
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(3, MockURLProtocol.receivedRequests.count)
        let createRequests = MockURLProtocol.receivedRequests.filter { request in
            request.httpMethod == "POST"
        }
        XCTAssertEqual(1, createRequests.count, "The POST method (create) should have been called only once")
    }
    
    func testClientThrowsErrorsWhenReceivingWrongOffset() throws {
        // Make sure that if a server gives a "wrong" offset, the uploader errors and doesn't end up in an infinite uploading loop.
        prepareNetworkForWrongOffset(data: data)
        try upload(data: data, shouldSucceed: false)
        XCTAssertEqual(1, tusDelegate.failedUploads.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterRetry() throws {
        // Make sure that chunking happens even after retries
        
        // We fail the client first, then restart and make it use a status call to continue
        // After which we make sure that calls get chunked properly.
        prepareNetworkForErronousResponses()
        let data = Fixtures.makeLargeData()
        let ids = try upload(data: data, shouldSucceed: false)
        
        // Now that a large upload failed. Let's retry a succesful upload, fetch its status, and check the requests that have been created.
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()
        
        try client.retry(id: ids[0])
        waitForUploadsToFinish(1)
        
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        XCTAssert(statusReqests.isEmpty)
        XCTAssertEqual(1, creationRequests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterFetchingStatus() throws {
        // First we make sure create succeeds. But uploading fails.
        // This means we can do a status call after. After which we measure if something will get chunked.
        prepareNetworkForFailingUploads()
        let data = Fixtures.makeLargeData()
        let ids = try upload(data: data, shouldSucceed: false)
        
        // Now a file is created with a remote url. So next fetch means the client will perform a status call.
        // Let's retry uploading and make sure that status and 2 (not 1, because chunking) calls have been made.
        
        prepareNetworkForSuccesfulStatusCall(data: data)
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()

        try client.retry(id: ids[0])
        waitForUploadsToFinish(1)
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        XCTAssert(creationRequests.isEmpty)
        XCTAssertEqual(1, statusReqests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    // MARK: - Custom URLs
    
    func testUploadingToCustomURL() throws {
        let url = URL(string: "www.custom-url")!
        try client.upload(data: data, uploadURL: url)
        waitForUploadsToFinish(1)
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(url, uploadRequests.first?.url)
    }
    
    // MARK: - Responses
    
    func testMakeSureClientCanHandleLowerCaseKeysInResponses() throws {
        prepareNetworkForSuccesfulUploads(data: data, lowerCasedKeysInResponses: true)
        try upload(data: data)
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
