import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals.
final class TUSClientTests: XCTestCase {
    
    let chunkSize: Int = 500 * 1024
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!
    
    override func setUp() {
        super.setUp()
        
        relativeStoragePath = URL(string: "TUSTEST")!
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        data = Data("abcdef".utf8)
        
        
        client = makeClient(storagePath: relativeStoragePath)
        
        MockURLProtocol.reset()
        prepareNetworkForSuccesfulUploads(data: data)
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset()
        clearDirectory(dir: fullStoragePath)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        clearDirectory(dir: cacheDir)
        do {
            try client.stopAndCancelAllUploads()
            try client.clearAllCache()
        } catch {
            //
        }
    }
    
    private func makeClient(storagePath: URL?) -> TUSClient {
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        
        // We don't use a live URLSession, we mock it out.
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: storagePath, session: URLSession.init(configuration: configuration))
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        return client
    }
    
    /// Server gives inappropriorate offsets
    /// - Parameter data: Data to upload
    private func prepareNetworkForWrongOffset(data: Data) {
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
        }
        
        // Mimick chunk uploading with offsets
        MockURLProtocol.prepareResponse(for: "PATCH") { headers in
            
            guard let headers = headers,
                  let strOffset = headers["Upload-Offset"],
                  let offset = Int(strOffset),
                  let strContentLength = headers["Content-Length"],
                  let contentLength = Int(strContentLength) else {
                      let error = "Did not receive expected Upload-Offset and Content-Length in headers"
                      XCTFail(error)
                      fatalError(error)
                  }
                  
            let newOffset = offset + contentLength - 1 // 1 offset too low. Trying to trigger potential inifnite upload loop. Which the client should handle, of course.
            print("total size is \(data.count) new offset is \(newOffset)")
            return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(newOffset)], data: nil)
        }
    }
    
    private func prepareNetworkForSuccesfulUploads(data: Data) {
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
        }
        
        // Mimick chunk uploading with offsets
        MockURLProtocol.prepareResponse(for: "PATCH") { headers in
            
            guard let headers = headers,
                  let strOffset = headers["Upload-Offset"],
                  let offset = Int(strOffset),
                  let strContentLength = headers["Content-Length"],
                  let contentLength = Int(strContentLength) else {
                      let error = "Did not receive expected Upload-Offset and Content-Length in headers"
                      XCTFail(error)
                      fatalError(error)
                  }
                  
            let newOffset = offset + contentLength
            return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(newOffset)], data: nil)
        }
        
    }
    
    private func prepareNetworkForErronousResponses() {
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
        MockURLProtocol.prepareResponse(for: "PATCH") { _ in
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
        MockURLProtocol.prepareResponse(for: "HEAD") { _ in
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
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
        let expectation = expectation(description: "Waiting for upload to finished")
        expectation.expectedFulfillmentCount = amount
        tusDelegate.finishUploadExpectation = expectation
        waitForExpectations(timeout: 6, handler: nil)
    }
    
    private func waitForUploadsToFail(_ amount: Int = 1) {
        let expectation = expectation(description: "Waiting for upload to fail")
        expectation.expectedFulfillmentCount = amount
        tusDelegate.uploadFailedExpectation = expectation
        waitForExpectations(timeout: 6, handler: nil)
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
    
    // MARK: - File handling
    
    func testClientCanHandleRelativeStoragelDirectories() throws {
        // Initialize tusclient with either "TUS" or "/TUS" and it should work
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let values = [
            (URL(string: "ABC")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "/ABC")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "ABC/")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "/ABC/")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "ABC/ZXC")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (URL(string: "/ABC/ZXC")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (URL(string: "ABC/ZXC/")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (URL(string: "/ABC/ZXC/")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (nil, documentsDirectory.appendingPathComponent("TUS")),
            (cacheDirectory.appendingPathComponent("TEST"), cacheDirectory.appendingPathComponent("TEST"))
            ]
        
        var clients = [TUSClient]()
        for (url, expectedPath) in values {
            clearDirectory(dir: expectedPath)
            
            let client = makeClient(storagePath: url)
            clients.append(client)
            
            let delegate = TUSMockDelegate()
            client.delegate = delegate
            
            try client.upload(data: data)
            
            var contents = try FileManager.default.contentsOfDirectory(at: expectedPath, includingPropertiesForKeys: nil)
            XCTAssertFalse(contents.isEmpty)
            
            let expectation = expectation(description: "Waiting for upload to finished")
            delegate.finishUploadExpectation = expectation
            waitForExpectations(timeout: 3, handler: nil)
            
            contents = try FileManager.default.contentsOfDirectory(at: expectedPath, includingPropertiesForKeys: nil)
            XCTAssert(contents.isEmpty)
            try client.stopAndCancelAllUploads()
            try client.clearAllCache()
            clearDirectory(dir: expectedPath)
        }
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
    
    // MARK: - Deletions / clearing cache
    
    func testClearingCache() throws {
        
        try makeDirectoryIfNeeded(url: fullStoragePath)
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty, "Prerequisite for tests fails. Expected dir to be empty \(String(describing: fullStoragePath))")
        
        let amount = 6
        for _ in 0..<amount {
            try client.upload(data: data)
        }
        
        waitForUploadsToFinish(amount)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty, "Contents expected to be empty. Instead got \(contents.count)")

        try client.clearAllCache()

        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
    }
    
    func testClearingEverythingAndStartingNewUploads () throws {
        // TODO: Make sure uploads are renewed. No lingering uploads.
        XCTFail("Implement me")
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
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // Store file in cache
        func storeFileInCache() throws -> URL {
            let targetLocation = cacheDir.appendingPathComponent("myfile.txt")
            try data.write(to: targetLocation)
            return targetLocation
        }
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
        
        let uploadCount = 5
        let url = try storeFileInCache()
        for _ in 0..<uploadCount {
            try client.uploadFileAt(filePath: url)
        }
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(uploadCount * 2, contents.count) // Every upload has a metadata file
        
        waitForUploadsToFinish(uploadCount)

        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
    }
    
    func testClientDeletesUploadedFilesOnStartup() throws {
        XCTFail("Implement me")
    }
    
    // MARK: - Retry mechanics
   
    func testClientRetriesOnFailure() throws {
        prepareNetworkForErronousResponses()
        
        let fileAmount = 2
        try upload(data: data, amount: fileAmount, shouldSucceed: false)
        
        let expectedRetryCount = 2
        XCTAssertEqual(fileAmount * (1 + expectedRetryCount), MockURLProtocol.receivedRequests.count)
    }
    
    func testMakeSureMetadataWithTooManyErrorsArentLoadedOnStart() throws {
        prepareNetworkForErronousResponses()
                                            
        XCTAssert(tusDelegate.failedUploads.isEmpty)
        
        let uploadCount = 5
        for _ in 0..<uploadCount {
            try client.upload(data: Data("hello".utf8))
        }
        
        let expectation = expectation(description: "Waiting for upload to fail")
        expectation.expectedFulfillmentCount = uploadCount
        tusDelegate.uploadFailedExpectation = expectation
        waitForExpectations(timeout: 3, handler: nil)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        
        XCTAssertEqual(uploadCount, tusDelegate.failedUploads.count)
        
        // Reload client, and see what happ
        client = makeClient(storagePath: relativeStoragePath)
        
        client.start()
        XCTAssert(tusDelegate.startedUploads.isEmpty)
    }
    
    // MARK: - Support custom headers
    
    func testUploadingWithCustomHeadersForData() throws {
        // Make sure client adds custom headers
        
        // Expected values
        let key = "TUSKit"
        let value = "TransloaditKit"
        let customHeaders = [key: value]
        
        let ids = try upload(data: data, amount: 2, customHeaders: customHeaders)
        
        // Validate
        let createRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(ids.count, createRequests.count)
        let allSatisfied = createRequests.allSatisfy { request in
            guard let headers = request.allHTTPHeaderFields else { return false }
            return headers[key] == value
        }
        
        XCTAssert(allSatisfied)
    }
    
    func testUploadingWithCustomHeadersForFiles() throws {
        // Make sure client adds custom headers
        
        // Expected values
        let key = "TUSKit"
        let value = "TransloaditKit"
        let customHeaders = [key: value]
        
        // Store file
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // Store file in cache
        func storeFileInCache() throws -> URL {
            let targetLocation = cacheDir.appendingPathComponent("myfile.txt")
            try data.write(to: targetLocation)
            return targetLocation
        }
        
        let location = try storeFileInCache()
        
        try client.uploadFileAt(filePath: location, customHeaders: customHeaders)
        waitForUploadsToFinish()
        
        // Validate
        let createRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(1, createRequests.count)
        let allSatisfied = createRequests.allSatisfy { request in
            guard let headers = request.allHTTPHeaderFields else { return false }
            return headers[key] == value
        }
        
        XCTAssert(allSatisfied)
    }

    // MARK: - Stopping and canceling
    
    func funcStopAndCancel() {
        XCTFail("Implement me")
        // Do we want delegate to report it all?
    }
    
    // MARK: - Testing new client sessions
    
    func testUploadIdsArePreservedBetweenSessions() throws {
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
        prepareNetworkForErronousResponses()
        
        let data = Data("hello".utf8)
        
        let amount = 5
        let ids = try (0..<amount).map { _ -> UUID in
            try client.upload(data: data)
        }
        
        waitForUploadsToFail(ids.count)

        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(ids.count, tusDelegate.failedUploads.count)
        
        // Reload client
        client = makeClient(storagePath: relativeStoragePath)
        XCTAssert(tusDelegate.startedUploads.isEmpty)

        prepareNetworkForSuccesfulUploads(data: data)

        for id in ids {
            try client.retry(id: id)
        }

        waitForUploadsToFinish(ids.count)

        XCTAssertEqual(ids.count, tusDelegate.finishedUploads.count, "Delegate has \(tusDelegate.activityCount) items")
    }
    
    // MARK: - Multiple instances
    
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
            try client.clearAllCache()
        } catch {
            //
        }

        contents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)

        otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)
        
        do {
            try otherClient.clearAllCache()
            try otherClient.stopAndCancelAllUploads()
        } catch {
            //
        }
    }
    
    // MARK: - Large files
    
    func testSmallUploadsArentChunked() throws {
        let ids = try upload(data: Data("012345678".utf8))
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(2, MockURLProtocol.receivedRequests.count)
    }
    
    func testClientContinuesPartialUploads() throws {
        // If server gives a content length lower than the data size, meaning a file isn't fully uploaded.
        // The client must continue uploading from that point on.
        // Even if the client attempted to upload the file in its entirety.
        // For instance, a connection could've been interrupted, so a file has to continue where it left off.
        XCTFail("Implement me")
    }
    
    func testLargeUploadsWillBeChunked() throws {
        // Above 500kb will be chunked

        let data = Data(repeatElement(1, count: chunkSize + 1))
        XCTAssert(data.count > chunkSize, "prerequisite failed")
        let ids = try upload(data: data)
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(3, MockURLProtocol.receivedRequests.count)
    }
    
    func testErrorsOnWrongOffset() throws {
        // Make sure that if a server gives a "wrong" offset, the uploader errors and doesn't end up in an infinite uploading loop.
        prepareNetworkForWrongOffset(data: data)
        try upload(data: data, shouldSucceed: false)
        XCTAssertEqual(1, tusDelegate.failedUploads.count)
    }
    
    func testMakeSureStartIsCalledOnceWhenUploadingInChunks() throws {
        XCTFail("Implement me")
    }
    
    func testLargeUploadsWillBeChunkedAfterFetchingStatus() throws {
        XCTFail("Implement me")
    }
    
}

private func makeDirectoryIfNeeded(url: URL) throws {
    let doesExist = FileManager.default.fileExists(atPath: url.path, isDirectory: nil)
    
    if !doesExist {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private func clearDirectory(dir: URL) {
    do {
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        for name in names
        {
            let path = "\(dir.path)/\(name)"
            try FileManager.default.removeItem(atPath: path)
        }
    } catch {
        print(error.localizedDescription)
    }
}
