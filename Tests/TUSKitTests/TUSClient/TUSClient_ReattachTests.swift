import XCTest
@testable import TUSKit

/// Upload tasks a background session finished or continued while the app wasn't running are re-attached when a
/// client starts. These tests leave a PATCH task in the session before the client exists, the way a relaunch finds
/// one, then let it complete.
final class TUSClient_ReattachTests: XCTestCase {

    var client: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var files: Files!
    var relativeStoragePath: URL!
    var mockTestID: String!
    var session: URLSession!
    var sessionDelegate: TUSAPI.SessionDataDelegate!
    let data = Data((0..<100).map { UInt8($0) })
    let remoteDestination = URL(string: "https://tus.example.net/files/reattached")!

    override func setUp() {
        super.setUp()
        relativeStoragePath = URL(string: UUID().uuidString)!
        mockTestID = UUID().uuidString
        MockURLProtocol.reset(testID: mockTestID)
        files = try! Files(storageDirectory: relativeStoragePath)
        clearDirectory(dir: files.storageDirectory)

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = [MockURLProtocol.testIDHeader: mockTestID!]
        sessionDelegate = TUSAPI.SessionDataDelegate()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

        // Accept every PATCH. The first one, already in flight when the client starts, answers only once the
        // client has had time to re-attach to it.
        var isFirstPatch = true
        MockURLProtocol.prepareResponse(for: "PATCH", testID: mockTestID) { headers in
            let offset = Int(headers?["Upload-Offset"] ?? "") ?? 0
            let length = Int(headers?["Content-Length"] ?? "") ?? 0
            defer { isFirstPatch = false }
            return MockURLProtocol.Response(status: 204, headers: ["Upload-Offset": String(offset + length)], data: nil,
                                            delay: isFirstPatch ? 1 : 0)
        }
    }

    override func tearDown() {
        super.tearDown()
        session.invalidateAndCancel()
        MockURLProtocol.reset(testID: mockTestID)
        clearDirectory(dir: files.storageDirectory)
    }

    func testReattachedTaskThatFinishesTheUploadReportsItOnce() throws {
        let metaData = try storeUpload(uploadedBytes: 0)
        let task = try makeInFlightPatch(for: metaData, range: 0..<100)
        task.resume()
        try startClient(chunkSize: 0)

        let finished = expectation(description: "didFinishUpload")
        tusDelegate.finishUploadExpectation = finished
        wait(for: [finished], timeout: 5)

        // Give a duplicate report time to arrive.
        let settle = expectation(description: "settle")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { settle.fulfill() }
        wait(for: [settle], timeout: 2)

        XCTAssertEqual(tusDelegate.finishedUploads.map(\.0), [metaData.id])
        XCTAssertEqual(tusDelegate.finishedUploads.first?.1, remoteDestination)
        XCTAssertEqual(try files.loadAllMetadata().count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: metaData.filePath.path))
    }

    func testReattachedChunkSchedulesTheNextChunk() throws {
        let metaData = try storeUpload(uploadedBytes: 25)
        let task = try makeInFlightPatch(for: metaData, range: 25..<50)
        task.resume()
        try startClient(chunkSize: 25)

        let finished = expectation(description: "didFinishUpload")
        tusDelegate.finishUploadExpectation = finished
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(patchOffsets(), ["25", "50", "75"])
        XCTAssertEqual(tusDelegate.finishedUploads.map(\.0), [metaData.id])
    }

    func testCancellingAReattachedUploadStopsIt() throws {
        let metaData = try storeUpload(uploadedBytes: 0)
        let task = try makeInFlightPatch(for: metaData, range: 0..<100)
        task.resume()
        try startClient(chunkSize: 0)

        try client.cancel(id: metaData.id)
        waitForCancelledRequest(task)

        XCTAssertTrue(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(patchOffsets(), ["0"])
        XCTAssertEqual(try files.loadAllMetadata().map(\.id), [metaData.id], "Cancelling keeps the upload for a later start()")
    }

    func testStoppingTheClientStopsAReattachedUpload() throws {
        let metaData = try storeUpload(uploadedBytes: 0)
        let task = try makeInFlightPatch(for: metaData, range: 0..<100)
        task.resume()
        try startClient(chunkSize: 0)

        client.stopAndCancelAll()
        waitForCancelledRequest(task)

        XCTAssertTrue(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(patchOffsets(), ["0"])
        XCTAssertEqual(try files.loadAllMetadata().map(\.id), [metaData.id])
    }

    func testCancellingAReattachedChunkDoesNotScheduleTheNextOne() throws {
        let metaData = try storeUpload(uploadedBytes: 25)
        let task = try makeInFlightPatch(for: metaData, range: 25..<50)
        task.resume()
        try startClient(chunkSize: 25)

        try client.cancel(id: metaData.id)
        waitForCancelledRequest(task)

        XCTAssertTrue(tusDelegate.finishedUploads.isEmpty)
        XCTAssertEqual(patchOffsets(), ["25"])
    }

    func testReattachedRequestThatFailsContinuesFromTheServerOffset() throws {
        // After a reboot the system sends the request again from the offset it started at, and the server, which
        // already has more than that, rejects it.
        var isFirstPatch = true
        MockURLProtocol.prepareResponse(for: "PATCH", testID: mockTestID) { headers in
            defer { isFirstPatch = false }
            if isFirstPatch {
                return MockURLProtocol.Response(status: 409, headers: [:], data: nil, delay: 1)
            }
            let offset = Int(headers?["Upload-Offset"] ?? "") ?? 0
            let length = Int(headers?["Content-Length"] ?? "") ?? 0
            return MockURLProtocol.Response(status: 204, headers: ["Upload-Offset": String(offset + length)], data: nil)
        }
        MockURLProtocol.prepareResponse(for: "HEAD", testID: mockTestID) { _ in
            MockURLProtocol.Response(status: 200, headers: ["Upload-Length": "100", "Upload-Offset": "60"], data: nil)
        }

        let metaData = try storeUpload(uploadedBytes: 0)
        let task = try makeInFlightPatch(for: metaData, range: 0..<100)
        task.resume()
        try startClient(chunkSize: 0)

        let finished = expectation(description: "didFinishUpload")
        tusDelegate.finishUploadExpectation = finished
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(patchOffsets(), ["0", "60"])
        XCTAssertEqual(tusDelegate.finishedUploads.map(\.0), [metaData.id])
    }

    // MARK: - Helpers

    /// Waits until `task` was cancelled, then for long enough that its response, a next chunk or a finished upload
    /// would have shown up if cancelling hadn't reached it.
    private func waitForCancelledRequest(_ task: URLSessionTask) {
        let settled = expectation(description: "settled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { settled.fulfill() }
        wait(for: [settled], timeout: 4)
        XCTAssertEqual((task.error as? URLError)?.code, .cancelled, "The re-attached request should be cancelled")
    }

    private func patchOffsets() -> [String] {
        MockURLProtocol.receivedRequests(testID: mockTestID)
            .filter { $0.httpMethod == "PATCH" }
            .compactMap { $0.value(forHTTPHeaderField: "Upload-Offset") }
    }

    /// Stores the file and metadata of an upload the server has already received `uploadedBytes` of.
    private func storeUpload(uploadedBytes: Int) throws -> UploadMetadata {
        let id = UUID()
        let path = try files.store(data: data, id: id)
        let metaData = UploadMetadata(id: id, filePath: path, uploadURL: remoteDestination, size: data.count, customHeaders: [:], mimeType: nil)
        metaData.remoteDestination = remoteDestination
        if uploadedBytes > 0 {
            metaData.uploadedRange = 0..<uploadedBytes
        }
        try files.encodeAndStore(metaData: metaData)
        return metaData
    }

    /// A PATCH for `range` running in the session, as a background session keeps one across a relaunch. The session
    /// only lists tasks that have been resumed, so callers resume it before starting the client.
    private func makeInFlightPatch(for metaData: UploadMetadata, range: Range<Int>) throws -> URLSessionUploadTask {
        let body = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data[range].write(to: body)
        addTeardownBlock { try? FileManager.default.removeItem(at: body) }

        var request = URLRequest(url: remoteDestination)
        request.httpMethod = "PATCH"
        request.setValue("1.0.0", forHTTPHeaderField: "TUS-Resumable")
        request.setValue("application/offset+octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(String(range.lowerBound), forHTTPHeaderField: "Upload-Offset")
        request.setValue(String(range.count), forHTTPHeaderField: "Content-Length")
        let task = session.uploadTask(with: request, fromFile: body)
        task.taskDescription = metaData.id.uuidString
        return task
    }

    /// Starts a client on the session, then routes the session's events to the client's API, as the system does
    /// for a background session on relaunch.
    private func startClient(chunkSize: Int) throws {
        client = try TUSClient(server: URL(string: "https://tus.example.net/files")!, storageDirectory: relativeStoragePath,
                               session: session, chunkSize: chunkSize)
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
        let api = try XCTUnwrap(Mirror(reflecting: client!).children.first { $0.label == "api" }?.value as? TUSAPI)
        sessionDelegate.api = api

        // Re-attaching is asynchronous: wait until the client has registered for the task.
        let registered = expectation(description: "callback registered")
        DispatchQueue.global().async {
            while !Self.hasCallbacks(api) { usleep(10_000) }
            registered.fulfill()
        }
        wait(for: [registered], timeout: 3)
    }

    private static func hasCallbacks(_ api: TUSAPI) -> Bool {
        // `callbacks` is only safe to read on the API's queue.
        let queue = Mirror(reflecting: api).children.first { $0.label == "queue" }?.value as! DispatchQueue
        return queue.sync {
            let callbacks = Mirror(reflecting: api).children.first { $0.label == "callbacks" }?.value as? [String: Any]
            return !(callbacks?.isEmpty ?? true)
        }
    }
}
