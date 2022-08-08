import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClientTests: XCTestCase {
    
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
    
    // MARK: - Stopping and canceling
    
    func testFuncStopAndCancel() throws {

        XCTAssert(tusDelegate.fileErrors.isEmpty)
        try client.upload(data: data)
        client.stopAndCancelAll()
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        XCTAssert(tusDelegate.fileErrors.isEmpty)
        
        // Test adding new uploads, make sure they work after stopping and cancelling
        try client.upload(data: data)

        waitForUploadsToFinish(1)
        XCTAssertEqual(1, tusDelegate.finishedUploads.count, "Expected the previous and new upload to finish")
    }
    
    func testCancelForID() throws {
        let taskIDtoCancel = try client.upload(data: data)
        
        try client.cancel(id: taskIDtoCancel)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        XCTAssert(tusDelegate.fileErrors.isEmpty)
    }
    
    // MARK: - Progress
    
    func testProgress() throws {
        let ids = try upload(data: data, amount: 2)
        
        // Progress is non-deterministic. But if there is any, we check if it's correct.
        for (id, progress) in tusDelegate.progressPerId {
            XCTAssert(ids.contains(id))
            XCTAssert(progress > 0)
        }
    }
    
    func testRemainingUploads() throws {
        XCTAssertEqual(0, client.remainingUploads)
        let numUploads = 2
        for _ in 0..<numUploads {
            try client.upload(data: data)
        }
        XCTAssertEqual(numUploads, client.remainingUploads)
        try client.reset()
        XCTAssertEqual(0, client.remainingUploads)
    }
    
    // MARK: - Supported Extensions
    
    func testClientExcludesCreationStep() throws {
        prepareNetworkForSuccesfulStatusCall(data: data)
        client = makeClient(storagePath: fullStoragePath, supportedExtensions: [])
        client.delegate = tusDelegate
        
        // Act
        try client.upload(data: data)
        waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssertFalse(MockURLProtocol.receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files" &&
            $0.allHTTPHeaderFields?["Upload-Extension"] == "creation"
        }))
    }
    
    func testClientIncludesCreationStep() throws {
        prepareNetworkForSuccesfulStatusCall(data: data)
        client = makeClient(storagePath: fullStoragePath, supportedExtensions: [.creation])
        client.delegate = tusDelegate
        
        // Act
        try client.upload(data: data)
        waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssert(MockURLProtocol.receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files" &&
            $0.allHTTPHeaderFields?["Upload-Extension"] == "creation"
        }))
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
    
    private func waitForUploadsToStart(_ amount: Int = 1) {
        let uploadStartedExpectation = expectation(description: "Waiting for upload to start")
        uploadStartedExpectation.expectedFulfillmentCount = amount
        tusDelegate.startUploadExpectation = uploadStartedExpectation
        waitForExpectations(timeout: 6, handler: nil)
    }
    
}
