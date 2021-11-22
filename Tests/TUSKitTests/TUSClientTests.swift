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
            try client.reset()
        } catch {
            // Some dirs may not exist, that's fine. We can ignore the error.
        }
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
            
            let uploadFinishedExpectation = expectation(description: "Waiting for upload to finished")
            delegate.finishUploadExpectation = uploadFinishedExpectation
            waitForExpectations(timeout: 3, handler: nil)
            
            contents = try FileManager.default.contentsOfDirectory(at: expectedPath, includingPropertiesForKeys: nil)
            XCTAssert(contents.isEmpty)
            try client.reset()
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
    
    /*
    // MARK: - Deletions / clearing cache
    
    func testClearingCache() throws {
        func getContents() throws -> [URL] {
            return try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        }
        
        XCTAssert(try getContents().isEmpty, "Prerequisite for tests fails. Expected dir to be empty \(String(describing: fullStoragePath))")
        
        let amount = 2
        for _ in 0..<amount {
            try client.upload(data: data)
        }
        
        XCTAssertFalse(try getContents().isEmpty, "Contents expected NOT to be empty.")
       
        waitForUploadsToFinish(2)

        try client.clearAllCache()
        XCTAssert(try getContents().isEmpty, "Expected clearing cache to empty the folder")
    }
    
    func testClearingUploadsAndStartingNewUploads () throws {
        // We make sure that once we start uploading, and cancel that.
        // Any new uploads shouldn't be affected by old ones.
        let firstId = try client.upload(data: data)
        try client.reset()
        
        let contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty, "Stopping and canceling should have cleared files")
        
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
        
        let uploadFailedExpectation = expectation(description: "Waiting for upload to fail")
        uploadFailedExpectation.expectedFulfillmentCount = uploadCount
        tusDelegate.uploadFailedExpectation = uploadFailedExpectation
        waitForExpectations(timeout: 3, handler: nil)
        
        XCTAssert(tusDelegate.finishedUploads.isEmpty)
        
        XCTAssertEqual(uploadCount, tusDelegate.failedUploads.count)
        
        // Reload client, and see what happens
        client = makeClient(storagePath: relativeStoragePath)
        
        client.start()
        XCTAssert(tusDelegate.startedUploads.isEmpty)
    }
    
    // MARK: - Ids on start
    
//    func testStartReturnsPreviouslyStoredIds() {
//        // TODO: Make sure that if you are going to upload, and then stop, and start again. That by starting the ids are properly returned.
////        let ids = client.start()
//        XCTFail("Implement me")
//    }
//
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
        
        for request in createRequests {
            let headers = try XCTUnwrap(request.allHTTPHeaderFields)
            let metaDataString = try XCTUnwrap(headers["Upload-Metadata"])
            for (key, value) in customHeaders {
                XCTAssert(metaDataString.contains(key), "Expected \(metaDataString) to contain \(key)")
                XCTAssert(metaDataString.contains(value.toBase64()), "Expected \(metaDataString) to contain base 64 value for \(value)")
            }
        }
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
        
        for request in createRequests {
            let headers = try XCTUnwrap(request.allHTTPHeaderFields)
            let metaDataString = try XCTUnwrap(headers["Upload-Metadata"])
            for (key, value) in customHeaders {
                XCTAssert(metaDataString.contains(key), "Expected \(metaDataString) to contain \(key)")
                XCTAssert(metaDataString.contains(value.toBase64()), "Expected \(metaDataString) to contain base 64 value for \(value)")
            }
        }
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
        
        waitForUploadsToFinish(2)
        XCTAssertEqual(2, tusDelegate.finishedUploads.count, "Expected the previous and new upload to finish")
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
            try otherClient.reset()
        } catch {
            //
        }
    }
    
    // MARK: - Chunking
    
    func testSmallUploadsArentChunked() throws {
        let ids = try upload(data: Data("012345678".utf8))
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(2, MockURLProtocol.receivedRequests.count)
    }
    
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

    func testLargeUploadsWillBeChunked() throws {
        // Above 500kb will be chunked
        let data = Fixtures.makeLargeData()
        
        XCTAssert(data.count > Fixtures.chunkSize, "prerequisite failed")
        let ids = try upload(data: data)
        XCTAssertEqual(1, ids.count)
        XCTAssertEqual(3, MockURLProtocol.receivedRequests.count)
        let createRequests = MockURLProtocol.receivedRequests.filter { request in
            request.httpMethod == "POST"
        }
        XCTAssertEqual(1, createRequests.count, "The POST method (create) should have been called only once")
    }
    
    func testClientThrowsErrorsWhenReceivingWrongOffset() throws {
        // Make sure that if a server gives a "wrong" offset, the uploader errors and doesn't end up in an infinite uploading loop.
        prepareNetworkForWrongOffset(data: data)
        try upload(data: data, shouldSucceed: false)
        XCTAssertEqual(1, tusDelegate.failedUploads.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterRetry() throws {
        // Make sure that chunking happens even after retries
        
        // We fail the client first, then restart and make it use a status call to continue
        // After which we make sure that calls get chunked properly.
        prepareNetworkForErronousResponses()
        let data = Fixtures.makeLargeData()
        let ids = try upload(data: data, shouldSucceed: false)
        
        // Now that a large upload failed. Let's retry a succesful upload, fetch its status, and check the requests that have been created.
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()
        
        try client.retry(id: ids[0])
        waitForUploadsToFinish(1)
        
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        XCTAssert(statusReqests.isEmpty)
        XCTAssertEqual(1, creationRequests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    func testLargeUploadsWillBeChunkedAfterFetchingStatus() throws {
        // First we make sure create succeeds. But uploading fails.
        // This means we can do a status call after. After which we measure if something will get chunked.
        prepareNetworkForFailingUploads()
        let data = Fixtures.makeLargeData()
        let ids = try upload(data: data, shouldSucceed: false)
        
        // Now a file is created with a remote url. So next fetch means the client will perform a status call.
        // Let's retry uploading and make sure that status and 2 (not 1, because chunking) calls have been made.
        
        prepareNetworkForSuccesfulStatusCall(data: data)
        prepareNetworkForSuccesfulUploads(data: data)
        resetReceivedRequests()

        try client.retry(id: ids[0])
        waitForUploadsToFinish(1)
        let statusReqests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "HEAD" }
        let creationRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "PATCH" }
        XCTAssert(creationRequests.isEmpty)
        XCTAssertEqual(1, statusReqests.count)
        XCTAssertEqual(2, uploadRequests.count)
    }
    
    // MARK: - Delegate start calls
    
    func testStartedUploadIsCalledOnceForLargeFile() throws {
        let data = Fixtures.makeLargeData()
        
        try upload(data: data)
        
        XCTAssertEqual(1, tusDelegate.startedUploads.count, "Expected start to be only called once for a chunked upload")
    }
    
    
    func testStartedUploadIsCalledOnceForLargeFileWhenUploadFails() throws {
        prepareNetworkForFailingUploads()
        // Even when retrying, start should only be called once.
        let data = Fixtures.makeLargeData()
        
        try upload(data: data, shouldSucceed: false)
        
        XCTAssertEqual(1, tusDelegate.startedUploads.count, "Expected start to be only called once for a chunked upload with errors")
    }
    
    // MARK: - Context
    
    // These tests are here to make sure you get the same context back that you passed to upload.
    
    func testContextIsReturnedAfterUploading() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        try client.upload(data: data, context: expectedContext)
        
        waitForUploadsToFinish()
        
        // One context for start, one for failure
        
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 2)),  "Expected the context to be returned once an upload is finished")
        
        try XCTAssertNoThrow(client.uploadFileAt(filePath: Fixtures.makeFilePath(), context: expectedContext), "TUSClient should accept files that exist")
        
        waitForUploadsToFinish()
        // Two contexts for start, two for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
        
    }
    
    func testContextIsReturnedAfterUploadingMultipleFiles() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        try client.uploadMultiple(dataFiles: [data, data], context: expectedContext)
        
        waitForUploadsToFinish(2)
        
        // Two contexts for start, two for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
        
        let path = try Fixtures.makeFilePath()
        try client.uploadFiles(filePaths: [path, path], context: expectedContext)
        waitForUploadsToFinish(2)
        
        // Four contexts for start, four for failure
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 8)), "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsGivenOnStart() throws {
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didStartExpectation = expectation(description: "Waiting for upload to start")
        didStartExpectation.expectedFulfillmentCount = files.count
        tusDelegate.startUploadExpectation = didStartExpectation
        try client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertEqual(tusDelegate.receivedContexts, [expectedContext, expectedContext], "Expected the context to be returned once an upload is finished")
    }
    
    func testContextIsGivenOnFailure() throws {
        prepareNetworkForFailingUploads()
        
        let expectedContext = ["I am a key" : "I am a value"]
        
        let files: [Data] = [data, data]
        let didFailExpectation = expectation(description: "Waiting for upload to start")
        didFailExpectation.expectedFulfillmentCount = files.count
        tusDelegate.uploadFailedExpectation = didFailExpectation
        try client.uploadMultiple(dataFiles: files, context: expectedContext)
        
        waitForExpectations(timeout: 3, handler: nil)
        // Expected the context 4 times. Two files on start, two files on error.
        XCTAssertEqual(tusDelegate.receivedContexts, Array(repeatElement(expectedContext, count: 4)), "Expected the context to be returned once an upload is finished")
    }
    
    // MARK: - Custom URLs
    
    func testUploadingToCustomURL() throws {
        let url = URL(string: "www.custom-url")!
        try client.upload(data: data, uploadURL: url)
        waitForUploadsToFinish(1)
        let uploadRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(url, uploadRequests.first?.url)
    }
    
    // MARK: - Responses
    
    func testMakeSureClientCanHandleLowerCaseKeysInResponses() throws {
        prepareNetworkForSuccesfulUploads(data: data, lowerCasedKeysInResponses: true)
        try upload(data: data)
    }
    
    // MARK: - Progress
    
    func testProgress() throws {
        let ids = try upload(data: data, amount: 2)
        
        // Progress is non-deterministic. But if there is any, we check if it's correct.
        for (id, progress) in tusDelegate.progressPerId {
            XCTAssert(ids.contains(id))
            XCTAssert(progress > 0)
        }
        
        XCTAssert(tusDelegate.totalProgressReceived.count > 1)
        XCTAssert(tusDelegate.totalProgressReceived.contains(data.count))
    }
    
    */
    
    // MARK: - Preparing network
    
    private func resetReceivedRequests() {
        MockURLProtocol.receivedRequests = []
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
            return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(newOffset)], data: nil)
        }
    }
    
    
    
    private func prepareNetworkForSuccesfulUploads(data: Data, lowerCasedKeysInResponses: Bool = false) {
        MockURLProtocol.prepareResponse(for: "POST") { _ in
            let key: String
            if lowerCasedKeysInResponses {
                key = "location"
            } else {
                key = "Location"
            }
            return MockURLProtocol.Response(status: 200, headers: [key: "www.somefakelocation.com"], data: nil)
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
            
            let key: String
            if lowerCasedKeysInResponses {
                key = "upload-offset"
            } else {
                key = "Upload-Offset"
            }
            return MockURLProtocol.Response(status: 200, headers: [key: String(newOffset)], data: nil)
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
    
    private func prepareNetworkForSuccesfulStatusCall(data: Data) {
        MockURLProtocol.prepareResponse(for: "HEAD") { _ in
            MockURLProtocol.Response(status: 200, headers: ["Upload-Length": String(data.count),
                                                            "Upload-Offset": "0"], data: nil)
        }
    }
    
    /// Create call can still succeed. This is useful for triggering a status call.
    private func prepareNetworkForFailingUploads() {
        // Upload means patch. Letting that fail.
        MockURLProtocol.prepareResponse(for: "PATCH") { _ in
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
}
