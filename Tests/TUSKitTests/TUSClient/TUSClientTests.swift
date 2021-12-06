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
    
    // MARK: - Flakey on CI, work fine locally
    
    /*
    func testClientContinuesPartialUploads() throws {
        // If server gives a content length lower than the data size, meaning a file isn't fully uploaded.
        // The client must continue uploading from that point on.
        // Even if the client attempted to upload the file in its entirety.
        // It's unlikely but client should be able to handle this.
        
        // We'll upload a tiny file, yet it will still a response from the server where it's not finished.
        // The client should then start a next upload.
        
        let data = Data("012345678".utf8)
        
        var isFirstUpload = true
        let firstOffset = data.count / 2
        
        // Mimick chunk uploading with offsets. Make sure initially we give a too low of an offset
        MockURLProtocol.prepareResponse(for: "PATCH") { headers in
            if isFirstUpload {
                isFirstUpload.toggle()
                return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(firstOffset)], data: nil)
            } else {
                return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(data.count)], data: nil)
            }
        }
        
        try upload(data: data)
        
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        XCTAssert(statusReqests.isEmpty)
        XCTAssertEqual(1, creationRequests.count)
        XCTAssertEqual(2, uploadRequests.count)
        
        let firstRequest = uploadRequests[0]
        let secondRequest = uploadRequests[1]
        
        XCTAssertEqual("0", firstRequest.allHTTPHeaderFields?["Upload-Offset"])
        XCTAssertEqual(String(firstOffset), secondRequest.allHTTPHeaderFields?["Upload-Offset"], "Even though first request wanted to upload to content length 9. We expect that on server returning \(firstOffset), that the second request continues from that. So should be \(firstOffset) here")
    }
     
    func testMultipleInstancesDontClashWithFilesIfPathsAreDifferent() throws {
        // Make multiple instances, they shouldn't interfere with each other's files.
        
        // Second instance
        let url = URL(string: "TUSTWO")!
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        otherClient = TUSClient(config: TUSConfig(server: URL(string: "www.tus.io")!), sessionIdentifier: "TEST", storageDirectory: url, session: URLSession.init(configuration: configuration))
        
        // Prerequisites
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let otherLocation = documentsDir.appendingPathComponent("TUSTWO")
        try? FileManager.default.removeItem(atPath: otherLocation.path)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: otherLocation.path, isDirectory: nil), "Prerequite failed, dir shouldn't exist yet in this test")

        for _ in 0..<6 {
            try client.upload(data: Data("abcdef".utf8))
            try otherClient.upload(data: Data("abcdef".utf8))
        }

        var otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)

        otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)

        // Now clear cache of first client, second should be unaffected
        do {
            try client.reset()
        } catch {
            //
        }

        contents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)

        otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)
        
        do {
            try otherClient.reset()
        } catch {
            //
        }
    }
     */
}
