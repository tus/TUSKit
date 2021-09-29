import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals.
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
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        data = Data("abcdef".utf8)
        prepareNetworkForSuccesfulUploads(data: data)
        
        client = makeClient(storagePath: relativeStoragePath)
        
    }
    
    override func tearDown() {
        super.tearDown()
        clearDirectory(dir: fullStoragePath)
    }
    
    private func makeClient(storagePath: URL) -> TUSClient {
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        
        // We don't use a live URLSession, we mock it out.
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: relativeStoragePath, session: URLSession.init(configuration: configuration))
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        return client
    }
    
    private func prepareNetworkForSuccesfulUploads(data: Data) {
        MockURLProtocol.receivedRequests = []
        MockURLProtocol.currentResponse = nil
        MockURLProtocol.responses = [:]
        MockURLProtocol.prepareResponse(for: "POST") {
            MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
        }
        
        
        MockURLProtocol.prepareResponse(for: "PATCH") {
            MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(data.count)], data: nil)
        }
        
    }
    
    private func prepareNetworkForFaultyUpload() {
        MockURLProtocol.prepareResponse(for: "POST") {
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
    }
    
    /// Upload data, a certain amount of times.
    private func upload(data: Data, amount: Int = 1) throws -> [UUID] {
        let ids = try (0..<amount).map { _ -> UUID in
            return try client.upload(data: data)
        }
        
        waitForUploadsToFinish(amount)

        return ids
    }
    
    private func waitForUploadsToFinish(_ amount: Int = 1) {
        let expectation = expectation(description: "Waiting for upload to finished")
        expectation.expectedFulfillmentCount = amount
        tusDelegate.finishUploadExpectation = expectation
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    private func waitForUploadsToFail(_ amount: Int = 1) {
        let expectation = expectation(description: "Waiting for upload to fail")
        expectation.expectedFulfillmentCount = amount
        tusDelegate.uploadFailedExpectation = expectation
        waitForExpectations(timeout: 3, handler: nil)
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
    
    func testClientCanHandleDirectoryStartingWithOrWithoutForwardSlash() {
        // Initialize tusclient with either "TUS" or "/TUS" and it should work
        XCTFail("Implement me")
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
        MockURLProtocol.prepareResponse(for: "POST") {
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
                                            
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
        
        for _ in 0..<6 {
            try client.upload(data: data)
        }
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)
        
        try client.clearAllCache()
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
    }
    
    func testClearingEverythingAndStartingNewUploads (){
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
        for _ in 0..<uploadCount {
            let url = try storeFileInCache()
            try client.uploadFileAt(filePath: url)
        }
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(uploadCount * 2, contents.count) // Every upload has a metadata file
        
        let expectation = expectation(description: "Waiting for upload to finished")
        expectation.expectedFulfillmentCount = uploadCount
        tusDelegate.finishUploadExpectation = expectation
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertEqual(5, tusDelegate.finishedUploads.count)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
    }
    
    func testDeleteUploadedFilesOnStartup() {
       XCTFail("Implement me")
    }
    
    // MARK: - Retry mechanics
   
    func testRetryMechanic() {
        // Count requests, see if you see returning ones on failure.
        // Count requests, see if you see one request on success.
        // Count requests, see if request if halfway a request succeeds (Before retry limit).
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsFollowRetryLimitAndAreUploadedAgain() {
        // Only for x amount of errors
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsAreRetriedXTimes() {
        // Only retry error upload x times
        XCTFail("Implement me")
    }
    
    func testClientDoesNotScheduleFilesThatArentFinished() {
        XCTFail("Implement me")
    }
    
    // MARK: - Support custom headers
    
    func testUploadingWithCustomHeaders() throws {
        // TODO: Only works in isolation. Check static receivedRequests
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
        
        let aCount = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }.count
        print("Count is \(aCount)")
        // Upload
        try client.upload(data: data, customHeaders: customHeaders)
        try client.uploadFileAt(filePath: location, customHeaders: customHeaders)
        
        waitForUploadsToFinish(2)
        
        // Validate
        // TODO: Possible create retry?
        let createRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(2, createRequests.count)
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
    
    func testMakeSureMetadataWithTooManyErrorsArentLoadedOnStart() throws {
        MockURLProtocol.prepareResponse(for: "POST") {
            MockURLProtocol.Response(status: 401, headers: [:], data: nil)
        }
                                            
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
    
    func testUploadIdsArePreservedBetweenSessions() throws {
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
        prepareNetworkForFaultyUpload()
        
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
        try client.clearAllCache()

        contents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)

        otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)
    }
    
    // MARK: - Large files
    
    func testUploadsCanBeChunked() throws {
        // TODO: Be sure to trigger multiple uploads (e.g. small chunk to upload, first offset is half of data, then complete)
        // TODO: Support MockURLProtocol to update the offset during uploads
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
