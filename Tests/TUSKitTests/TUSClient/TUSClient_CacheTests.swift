import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_CacheTests: XCTestCase {
    
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

    // MARK: - Deletions / clearing cache
    
    func testClearsCacheOfUnfinishedUploads() async throws {
        
        verifyTheStorageIsEmpty()
        
        let amount = 2
        for _ in 0..<amount {
            try await client.upload(data: data)
        }
        
        verifyTheStorageIsNOTEmpty()
        
        await client.stopAndCancelAll()
        
        try await clearCache()

        verifyTheStorageIsEmpty()
    }
    
    func testClearingUploadsAndStartingNewUploads () async throws {
        // We make sure that once we start uploading, and cancel that.
        // Any new uploads shouldn't be affected by old ones.
        let firstId = try await client.upload(data: data)
        try await client.reset()
        
        verifyTheStorageIsEmpty()
        
        let secondId = try await upload(data: data)[0]
        XCTAssertEqual(1, tusDelegate.finishedUploads.count)
        XCTAssertNotEqual(firstId, secondId)
    }
    
    func testDeleteSingleFile() async throws {
        let id = try await client.upload(data: data)
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(2, contents.count, "Prerequisite for tests fails, expected 2 files to exist, the file to upload and metadata")
        
        try await client.removeCacheFor(id: id)
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        
        XCTAssert(contents.isEmpty, "Expected the client to delete the file")
    }

    func testClientDeletesFilesOnCompletion() async throws {
        // If a file is done uploading (as said by status), but not yet deleted.
        // Then the file can be deleted right after fetching the status.
        
        // Create isolated dir for this test, in case of parallelism issues.
        let storagePath = URL(string: "DELETE_ME")!
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fullStoragePath = docDir.appendingPathComponent(storagePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)

        client = makeClient(storagePath: storagePath)
        tusDelegate = TUSMockDelegate()
        await client.setDelegate(tusDelegate)
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
        
        try await client.upload(data: data)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(2, contents.count) // Every upload has a metadata file

        await waitForUploadsToFinish(1)

        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
    }

    private func waitForUploadsToFinish(_ amount: Int = 1) async {
        let uploadExpectation = expectation(description: "Waiting for upload to finished")
        uploadExpectation.expectedFulfillmentCount = amount
        tusDelegate.finishUploadExpectation = uploadExpectation
        await fulfillment(of: [tusDelegate.finishUploadExpectation!], timeout: 6)
    }
    
    private func waitForUploadsToFail(_ amount: Int = 1) async {
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = amount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        await fulfillment(of: [tusDelegate.uploadFailedExpectation!], timeout: 6)
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
    
    private func clearCache() async throws {
        do {
            try await client.clearAllCache()
        } catch {
            // Sometimes we get file permission errors, retry
            try? await client.clearAllCache()
        }
        
    }
    
}
