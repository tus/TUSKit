import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_RetryTests: XCTestCase {
    
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
    
    func testClientRetriesOnFailure() async throws {
        prepareNetworkForErronousResponses()
        
        let fileAmount = 2
        try await upload(data: data, amount: fileAmount, shouldSucceed: false)
        
        let expectedRetryCount = 2
        XCTAssertEqual(fileAmount * (1 + expectedRetryCount), MockURLProtocol.receivedRequests.count)
    }
    
    func testMakeSureMetadataWithTooManyErrorsArentLoadedOnStart() async throws {
        prepareNetworkForErronousResponses()
                                            
        // Pre-assertions
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        
        let uploadCount = 5
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = uploadCount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        
        for _ in 0..<uploadCount {
            try await client.upload(data: Data("hello".utf8))
        }
        
        await fulfillment(of: [uploadFailedExpectation])
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(uploadCount, tusDelegate.failedUploads.count)
        
        // Reload client, and see what happens
        client = makeClient(storagePath: relativeStoragePath)
        
        await client.start()
        XCTAssert(tusDelegate.startedUploads.isEmpty)
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
