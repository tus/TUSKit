import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_IdsTests: XCTestCase {
    
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
    
    // MARK: - Testing new client sessions
    
    func testUploadIdsArePreservedBetweenSessions() throws {
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
        prepareNetworkForErronousResponses()
        
        let ids = try upload(data: data, amount: 2, customHeaders: [:], shouldSucceed: false)

        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(ids.count, tusDelegate.failedUploads.count)
        
        // Reload client
        client = makeClient(storagePath: relativeStoragePath)
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate

        XCTAssert(tusDelegate.startedUploads.isEmpty)

        prepareNetworkForSuccesfulUploads(data: data)

        for id in ids {
            try client.retry(id: id)
        }

        waitForUploadsToFinish(ids.count)

        XCTAssertEqual(ids.count, tusDelegate.finishedUploads.count, "Delegate has \(tusDelegate.activityCount) items")
    }
    
    // MARK: - Id handling
    
    func testIdsAreGivenAndReturnedWhenFinished() throws {
        
        // Make sure id's that are given when uploading, are returned when uploads are finished
        let expectedId = try client.upload(data: data)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        
        tusDelegate.finishUploadExpectation = expectation(description: "Waiting for upload to fail")
        waitForExpectations(timeout: 3, handler: nil)
        
        XCTAssert(tusDelegate.failedUploads.isEmpty, "Found a failed uploads, should have been empty. Something went wrong with uploading.")
        XCTAssertEqual(1, tusDelegate.finishedUploads.count, "Upload didn't finish.")
        for (id, _) in tusDelegate.finishedUploads {
            XCTAssertEqual(id, expectedId)
        }
    }
    
    func testCorrectIdsAreGivenOnFailure() throws {
        prepareNetworkForErronousResponses()
                                            
        let expectedId = try client.upload(data: Data("hello".utf8))
        
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        
        tusDelegate.uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        
        XCTAssertEqual(1, tusDelegate.failedUploads.count)
        for (id, _) in tusDelegate.failedUploads {
            XCTAssertEqual(id, expectedId)
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
