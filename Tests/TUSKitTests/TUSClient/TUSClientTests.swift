import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClientTests: XCTestCase {
    
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
    
    override func tearDown() {
        super.tearDown()
        clearDirectory(dir: fullStoragePath)
    }
    
    // MARK: - Stopping and canceling
    
    func testFuncStopAndCancel() async throws {

        XCTAssert(tusDelegate.fileErrors.isEmpty)
        try await client.upload(data: data)
        await client.stopAndCancelAll()
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        XCTAssert(tusDelegate.fileErrors.isEmpty)
        
        // Test adding new uploads, make sure they work after stopping and cancelling
        try await client.upload(data: data)

        await waitForUploadsToFinish(1)
        XCTAssertEqual(1, tusDelegate.finishedUploads.count, "Expected the previous and new upload to finish")
    }
    
    func testCancelForID() async throws {
        let taskIDtoCancel = try await client.upload(data: data)
        
        await client.cancel(id: taskIDtoCancel)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        XCTAssert(tusDelegate.fileErrors.isEmpty)
    }
    
    // MARK: - Progress
    
    func testProgress() async throws {
        let ids = try await upload(data: data, amount: 2)
        
        // Progress is non-deterministic. But if there is any, we check if it's correct.
        for (id, progress) in tusDelegate.progressPerId {
            XCTAssert(ids.contains(id))
            XCTAssert(progress > 0)
        }
    }
    
    func testRemainingUploads() async throws {
        var remainingUploads = await client.remainingUploads
        XCTAssertEqual(0, remainingUploads)
        
        let numUploads = 2
        for _ in 0..<numUploads {
            try await client.upload(data: data)
        }
        remainingUploads = await client.remainingUploads
        XCTAssertEqual(numUploads, remainingUploads)
        
        try await client.reset()
        remainingUploads = await client.remainingUploads
        XCTAssertEqual(0, remainingUploads)
    }
    
    func testgetStoredUploads() async throws {
        let taskIDtoCancel = try await client.upload(data: data)
        await client.cancel(id: taskIDtoCancel)
        let storedUploads = try await client.getStoredUploads()

        XCTAssert(storedUploads.contains(where: { $0.id == taskIDtoCancel }))
    }
    
    // MARK: - Supported Extensions
    
    func testClientExcludesCreationStep() async throws {
        prepareNetworkForSuccesfulStatusCall(data: data)
        client = makeClient(storagePath: fullStoragePath, supportedExtensions: [])
        await client.setDelegate(tusDelegate)
        
        // Act
        try await client.upload(data: data)
        await waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssertFalse(MockURLProtocol.receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files"
        }))
    }
    
    func testClientIncludesCreationStep() async throws {
        prepareNetworkForSuccesfulStatusCall(data: data)
        client = makeClient(storagePath: fullStoragePath, supportedExtensions: [.creation])
        await client.setDelegate(tusDelegate)
        
        // Act
        try await client.upload(data: data)
        await waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssert(MockURLProtocol.receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files"
        }))
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
    
    private func waitForUploadsToStart(_ amount: Int = 1) async {
        let uploadStartedExpectation = expectation(description: "Waiting for upload to start")
        uploadStartedExpectation.expectedFulfillmentCount = amount
        tusDelegate.startUploadExpectation = uploadStartedExpectation
        await fulfillment(of: [uploadStartedExpectation], timeout: 6)
    }
    
}
