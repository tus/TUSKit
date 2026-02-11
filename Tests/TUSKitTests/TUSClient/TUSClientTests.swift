import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClientTests: XCTestCase {
    
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

    func testHeavyUploadAndNoCrash() throws {
        // Test adding new uploads, make sure they work after stopping and cancelling
        for _ in 0..<1000 {
            try client.upload(data: data)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)){
            self.client.stopAndCancelAll()
        }

        waitForUploadsToFinish(1000)
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
    
    func testgetStoredUploads() throws {
        let taskIDtoCancel = try client.upload(data: data)
        try client.cancel(id: taskIDtoCancel)
        let storedUploads = try client.getStoredUploads()

        XCTAssert(storedUploads.contains(where: { $0.id == taskIDtoCancel }))
    }
    
    // MARK: - Supported Extensions
    
    func testClientExcludesCreationStep() throws {
        prepareNetworkForSuccesfulStatusCall(data: data, testID: mockTestID)
        client = makeClient(storagePath: fullStoragePath,
                            supportedExtensions: [],
                            sessionIdentifier: "TEST-\(mockTestID!)",
                            mockTestID: mockTestID)
        client.delegate = tusDelegate
        
        // Act
        try client.upload(data: data)
        waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssertFalse(receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files"
        }))
    }
    
    func testClientIncludesCreationStep() throws {
        prepareNetworkForSuccesfulStatusCall(data: data, testID: mockTestID)
        client = makeClient(storagePath: fullStoragePath,
                            supportedExtensions: [.creation],
                            sessionIdentifier: "TEST-\(mockTestID!)",
                            mockTestID: mockTestID)
        client.delegate = tusDelegate
        
        // Act
        try client.upload(data: data)
        waitForUploadsToFinish()
        
        // Assert (ensure that the create HTTP request has not been called)
        XCTAssert(receivedRequests.contains(where: {
            $0.httpMethod == "POST" &&
            $0.url?.absoluteString == "https://tusd.tusdemo.net/files"
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
