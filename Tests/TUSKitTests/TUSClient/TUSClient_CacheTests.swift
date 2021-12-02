import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_CacheTests: XCTestCase {
    
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

    // MARK: - Deletions / clearing cache
    
    func testClearsCacheOfUnfinishedUploads() throws {
        
        verifyTheStorageIsEmpty()
        
        let amount = 2
        for _ in 0..<amount {
            try client.upload(data: data)
        }
        
        verifyTheStorageIsNOTEmpty()
        
        client.stopAndCancelAll()
        
        clearCache()

        verifyTheStorageIsEmpty()
    }
    
    func testClearingUploadsAndStartingNewUploads () throws {
        // We make sure that once we start uploading, and cancel that.
        // Any new uploads shouldn't be affected by old ones.
        let firstId = try client.upload(data: data)
        try client.reset()
        
        verifyTheStorageIsEmpty()
        
        let secondId = try upload(data: data)[0]
        XCTAssertEqual(1, tusDelegate.finishedUploads.count)
        XCTAssertNotEqual(firstId, secondId)
    }
    
    func testDeleteSingleFile() throws {
        let id = try client.upload(data: data)
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(2, contents.count, "Prerequisite for tests fails, expected 2 files to exist, the file to upload and metadata")
        
        try client.removeCacheFor(id: id)
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        
        XCTAssert(contents.isEmpty, "Expected the client to delete the file")
    }

    func testClientDeletesFilesOnCompletion() throws {
        // If a file is done uploading (as said by status), but not yet deleted.
        // Then the file can be deleted right after fetching the status.
        
        // Create isolated dir for this test, in case of parallelism issues.
        let storagePath = URL(string: "DELETE_ME")!
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fullStoragePath = docDir.appendingPathComponent(storagePath.absoluteString)

        client = makeClient(storagePath: storagePath)
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
        
        try client.upload(data: data)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(2, contents.count) // Every upload has a metadata file

        waitForUploadsToFinish(1)

        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
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
    
    // MARK: Storage helpers
    
    private func verifyTheStorageIsNOTEmpty() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
            XCTAssertFalse(contents.isEmpty)
        } catch {
            XCTFail("Expected to load contents, error is \(error)")
        }
    }
    
    private func verifyTheStorageIsEmpty() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
            XCTAssert(contents.isEmpty)
        } catch {
            // No dir is fine
        }
    }
    
    private func clearCache() {
        do {
            try client.clearAllCache()
        } catch {
            // Sometimes we get file permission errors, retry
            try? client.clearAllCache()
        }
        
    }
    
}
