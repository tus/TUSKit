import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals.
final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    
    override func setUp() {
        super.setUp()
        
        relativeStoragePath = URL(string: "TUSTEST")!
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        
        clearDirectory(dir: fullStoragePath)
        
        client = makeClient(storagePath: relativeStoragePath)
        
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    private func makeClient(storagePath: URL) -> TUSClient {
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        
        // We don't use a live URLSession, we mock it out.
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        return TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: relativeStoragePath, session: URLSession.init(configuration: configuration))
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
    
    func testUploadsCanBeChunked() throws {
        // TODO: Be sure to trigger multiple uploads (e.g. small chunk to upload, first offset is half of data, then complete)
        // TODO: Support MockURLProtocol to update the offset during uploads
        XCTFail("Implement me")
    }
    
    // MARK: - File handling
    
    func testClientCanHandleDirectoryStartingWithOrWithoutForwardSlash() {
        // Initialize tusclient with either "TUS" or "/TUS" and it should work
        XCTFail("Implement me")
    }
    
    // MARK: - Id handling
    
    func testIdsAreGivenAndReturnedWhenFinished() throws {
        
        let data = Data("hello".utf8)
        
        MockURLProtocol.prepareResponse(for: "POST") {
            MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
        }
        
        MockURLProtocol.prepareResponse(for: "PATCH") {
            MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(data.count)], data: nil)
        }
        
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
            try client.upload(data: Data("abcdef".utf8))
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
        let data = Data("abc".utf8)
        let id = try client.upload(data: data)
        
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertEqual(2, contents.count, "Prerequisite for tests fails, expected 2 files to exist, the file to upload and metadata")
        
        try client.removeCacheFor(id: id)
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        
        XCTAssert(contents.isEmpty, "Expected the client to delete the file")
    }

    func testClientDeletesFilesOnCompletion() {
        // If a file is done uploading (as said by status), but not yet deleted.
        // Then the file can be deleted right after fetching the status.
        XCTFail("Implement me")
    }
    
    func testDeleteUploadedFilesOnStartup() {
       XCTFail("Implement me")
    }
    
    // MARK: - Retry mechanics
   
    func testRetryMechanic() {
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
    
    func testUploadingWithCustomHeaders() {
        // Make sure client adds custom headers
        XCTFail("Implement me")
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
    
    func testUploadIdsArePreservedBetweenSessions() {
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
        
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
        
        
        XCTFail("Implement me")
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
