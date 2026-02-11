import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_RetryTests: XCTestCase {
    
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
        MockURLProtocol.reset(testID: mockTestID)
        clearDirectory(dir: fullStoragePath)
    }
    
    func testClientRetriesOnFailure() throws {
        prepareNetworkForErronousResponses(testID: mockTestID)
        
        let fileAmount = 2
        try upload(data: data, amount: fileAmount, shouldSucceed: false)
        
        let expectedRetryCount = 2
        XCTAssertEqual(fileAmount * (1 + expectedRetryCount), receivedRequests.count)
    }
    
    func testMakeSureMetadataWithTooManyErrorsArentLoadedOnStart() throws {
        prepareNetworkForErronousResponses(testID: mockTestID)
                                            
        // Pre-assertions
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        
        let uploadCount = 5
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = uploadCount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        
        for _ in 0..<uploadCount {
            try client.upload(data: Data("hello".utf8))
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(uploadCount, tusDelegate.failedUploads.count)
        
        // Reload client, and see what happens
        client = makeClient(storagePath: relativeStoragePath,
                            sessionIdentifier: "TEST-\(mockTestID!)",
                            mockTestID: mockTestID)
        
        client.start()
        XCTAssert(tusDelegate.startedUploads.isEmpty)
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
