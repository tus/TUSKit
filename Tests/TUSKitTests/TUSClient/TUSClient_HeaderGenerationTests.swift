import XCTest
import TUSKit

/// Tests around the upcoming header generation hook so that we can evolve the behaviour safely.
final class TUSClient_HeaderGenerationTests: XCTestCase {

    var client: TUSClient!
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

        tusDelegate = TUSMockDelegate()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset(testID: mockTestID)
        clearDirectory(dir: fullStoragePath)
        client = nil
    }

    /// Verifies the generator receives exactly the caller supplied custom headers and the upload identifier for correlation.
    func testGenerateHeadersReceivesOnlyCallerSuppliedHeaders() throws {
        let configuration = makeConfiguration()

        let expectedHeaders = [
            "Authorization": "Bearer token",
            "X-Trace-ID": "trace-123",
        ]
        var receivedHeaders: [String: String]?
        var receivedRequestID: UUID?
        let generatorCalled = expectation(description: "Header generator called")

        client = try makeClient(configuration: configuration) { requestID, headers, onHeadersGenerated in
            receivedRequestID = requestID
            receivedHeaders = headers
            onHeadersGenerated(headers)
            generatorCalled.fulfill()
        }
        client.delegate = tusDelegate

        let uploadID = try client.upload(data: data, customHeaders: expectedHeaders)

        wait(for: [generatorCalled], timeout: 1)
        XCTAssertEqual(receivedHeaders, expectedHeaders)
        XCTAssertEqual(receivedRequestID, uploadID)
    }

    /// Verifies the generator is called even when no custom headers were supplied, enabling clients to inject headers.
    func testGenerateHeadersCalledWithoutCustomHeaders() throws {
        let configuration = makeConfiguration()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let generatorCalled = expectation(description: "Header generator should be invoked")
        tusDelegate.finishUploadExpectation = expectation(description: "Upload finished")

        var firstReceivedHeaders: [String: String]?
        var fulfilledGenerator = false
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            if !fulfilledGenerator {
                firstReceivedHeaders = headers
                generatorCalled.fulfill()
                fulfilledGenerator = true
            }
            onHeadersGenerated(["Authorization": "Bearer injected"])
        }
        client.delegate = tusDelegate

        XCTAssertNoThrow(try client.upload(data: data))
        wait(for: [generatorCalled, tusDelegate.finishUploadExpectation!], timeout: 5)

        XCTAssertEqual(firstReceivedHeaders ?? [:], [:])
        let createRequests = receivedRequests.filter { $0.httpMethod == "POST" }
        XCTAssertFalse(createRequests.isEmpty)
        guard let postHeaders = createRequests.first?.allHTTPHeaderFields else {
            XCTFail("Expected POST request headers")
            return
        }
        XCTAssertEqual(postHeaders["Authorization"], "Bearer injected")
    }

    /// Ensures the generator receives the headers that were actually used on the previous request when retrying.
    func testGenerateHeadersReceivesLastAppliedValuesOnAutomaticRetry() throws {
        let configuration = makeConfiguration()

        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)
        prepareNetworkForFailingUploads(testID: mockTestID)

        var receivedAuthorizationHeaders: [String] = []
        let generatorCalledTwice = expectation(description: "Header generator called twice")
        generatorCalledTwice.expectedFulfillmentCount = 2
        var trackedCalls = 0

        let uploadFailed = expectation(description: "Upload should fail after retries")
        tusDelegate.uploadFailedExpectation = uploadFailed

        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            let current = headers["Authorization"] ?? ""
            receivedAuthorizationHeaders.append(current)
            let nextValue = current.isEmpty ? "Bearer mutated\(receivedAuthorizationHeaders.count)" : "\(current)-mutated\(receivedAuthorizationHeaders.count - 1)"
            onHeadersGenerated(["Authorization": nextValue])
            if trackedCalls < 2 {
                generatorCalledTwice.fulfill()
            }
            trackedCalls += 1
        }
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: ["Authorization": "Bearer original"])

        wait(for: [uploadFailed, generatorCalledTwice], timeout: 5)
        XCTAssertGreaterThanOrEqual(receivedAuthorizationHeaders.count, 2)
        XCTAssertEqual(receivedAuthorizationHeaders[0], "Bearer original")
        XCTAssertEqual(receivedAuthorizationHeaders[1], "Bearer original-mutated0")
    }

    /// Ensures resuming an upload reuses the previously applied headers.
    func testGenerateHeadersCalledWhenResumingUpload() throws {
        let configuration = makeConfiguration()

        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let firstGeneratorCalled = expectation(description: "First header generator called")
        let uploadStarted = expectation(description: "Upload started before pausing")
        tusDelegate.startUploadExpectation = uploadStarted

        var firstFulfilled = false
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            onHeadersGenerated(["Authorization": "Bearer resume-mutated"])
            if !firstFulfilled {
                firstFulfilled = true
                firstGeneratorCalled.fulfill()
            }
        }
        client.delegate = tusDelegate

        let uploadID = try client.upload(data: data, customHeaders: ["Authorization": "Bearer resume"])
        wait(for: [firstGeneratorCalled, uploadStarted], timeout: 5)
        client.stopAndCancelAll()

        MockURLProtocol.reset(testID: mockTestID)
        prepareNetworkForSuccesfulStatusCall(data: data, testID: mockTestID)
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        tusDelegate = TUSMockDelegate()
        let finishExpectation = expectation(description: "Upload should finish after resume")
        tusDelegate.finishUploadExpectation = finishExpectation

        var resumedHeaders: [String] = []
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            resumedHeaders.append(headers["Authorization"] ?? "")
            onHeadersGenerated(headers)
        }
        client.delegate = tusDelegate

        let resumedUploads = client.start().map(\.0)
        XCTAssertTrue(resumedUploads.contains(uploadID))
        wait(for: [finishExpectation], timeout: 5)
        XCTAssertFalse(resumedHeaders.isEmpty)
        XCTAssertEqual(resumedHeaders.first, "Bearer resume-mutated")
    }

    /// Ensures uploads wait for asynchronous header generation before proceeding.
    func testGenerateHeadersSupportsAsynchronousCompletion() throws {
        let configuration = makeConfiguration()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let asyncExpectation = expectation(description: "Async header generator invoked")
        asyncExpectation.expectedFulfillmentCount = 2
        let finishExpectation = expectation(description: "Upload finished")
        tusDelegate.finishUploadExpectation = finishExpectation

        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                asyncExpectation.fulfill()
                onHeadersGenerated(headers.merging(["Authorization": "Bearer async"]) { _, new in new })
            }
        }
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: ["Authorization": "Bearer original"])
        wait(for: [asyncExpectation, finishExpectation], timeout: 5)
    }

    /// Ensures the generator only receives caller-supplied headers during upload creation.
    func testGenerateHeadersReceivesOnlyCustomHeadersDuringCreate() throws {
        let configuration = makeConfiguration()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let customHeaders = ["Authorization": "Bearer foo", "X-Trace": "123"]
        var observedHeaders: [[String: String]] = []
        let createGeneratorCalled = expectation(description: "Header generator called during create")

        var createInvocationRecorded = false
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            if !createInvocationRecorded {
                observedHeaders.append(headers)
                createInvocationRecorded = true
                createGeneratorCalled.fulfill()
            }
            onHeadersGenerated(headers)
        }
        tusDelegate.finishUploadExpectation = expectation(description: "Upload finished")
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: customHeaders)
        wait(for: [createGeneratorCalled, tusDelegate.finishUploadExpectation!], timeout: 5)

        XCTAssertEqual(observedHeaders.first, customHeaders)
    }

    /// Ensures the generator only receives caller-supplied headers when a status check runs.
    func testGenerateHeadersReceivesOnlyCustomHeadersDuringStatus() throws {
        let configuration = makeConfiguration()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let customHeaders = ["Authorization": "Bearer bar", "X-Trace": "resume-123"]
        tusDelegate.startUploadExpectation = expectation(description: "Upload started")

        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            onHeadersGenerated(headers)
        }
        client.delegate = tusDelegate

        let uploadID = try client.upload(data: data, customHeaders: customHeaders)
        wait(for: [tusDelegate.startUploadExpectation!], timeout: 5)
        client.stopAndCancelAll()

        MockURLProtocol.reset(testID: mockTestID)
        prepareNetworkForSuccesfulStatusCall(data: data, testID: mockTestID)
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        tusDelegate = TUSMockDelegate()
        let statusGeneratorCalled = expectation(description: "Header generator called during status")
        let finishExpectation = expectation(description: "Upload finished after status")
        tusDelegate.finishUploadExpectation = finishExpectation

        var observedHeaders: [[String: String]] = []
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            observedHeaders.append(headers)
            onHeadersGenerated(headers)
            if observedHeaders.count == 1 {
                statusGeneratorCalled.fulfill()
            }
        }
        client.delegate = tusDelegate

        let resumedUploads = client.start().map(\.0)
        XCTAssertTrue(resumedUploads.contains(uploadID))
        wait(for: [statusGeneratorCalled, finishExpectation], timeout: 5)
        XCTAssertEqual(observedHeaders.first, customHeaders)
    }

    /// Ensures the generator only receives caller-supplied headers during the upload (PATCH) step.
    func testGenerateHeadersReceivesOnlyCustomHeadersDuringUpload() throws {
        let configuration = makeConfiguration()
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let customHeaders = ["Authorization": "Bearer data", "X-Trace": "upload-step"]
        tusDelegate.finishUploadExpectation = expectation(description: "Upload finished")

        var uploadHeaders: [[String: String]] = []
        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            uploadHeaders.append(headers)
            onHeadersGenerated(headers)
        }
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: customHeaders)
        wait(for: [tusDelegate.finishUploadExpectation!], timeout: 5)

        XCTAssertTrue(uploadHeaders.contains(customHeaders))
    }

    /// Ensures the generator cannot override headers that TUSClient manages itself.
    func testGenerateHeadersCannotOverrideReservedHeaders() throws {
        let configuration = makeConfiguration()
        MockURLProtocol.reset(testID: mockTestID)
        prepareNetworkForSuccesfulUploads(data: data, testID: mockTestID)

        let customHeaders = ["Authorization": "Bearer original"]
        tusDelegate.finishUploadExpectation = expectation(description: "Upload finished")

        client = try makeClient(configuration: configuration) { _, headers, onHeadersGenerated in
            var newHeaders = headers
            newHeaders["Authorization"] = "Bearer mutated"
            newHeaders["Upload-Offset"] = "999"
            onHeadersGenerated(newHeaders)
        }
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: customHeaders)
        wait(for: [tusDelegate.finishUploadExpectation!], timeout: 5)

        let patchRequests = receivedRequests.filter { $0.httpMethod == "PATCH" }
        XCTAssertFalse(patchRequests.isEmpty)
        guard let patchHeaders = patchRequests.first?.allHTTPHeaderFields else {
            XCTFail("Expected PATCH request headers")
            return
        }
        XCTAssertEqual(patchHeaders["Authorization"], "Bearer mutated")
        XCTAssertNotEqual(patchHeaders["Upload-Offset"], "999")
    }

    private func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        if let mockTestID {
            configuration.httpAdditionalHeaders = [MockURLProtocol.testIDHeader: mockTestID]
        }
        return configuration
    }

    private func makeClient(configuration: URLSessionConfiguration? = nil,
                            generateHeaders: HeaderGenerationHandler? = nil) throws -> TUSClient {
        let configuration = configuration ?? makeConfiguration()
        return try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST-\(mockTestID!)",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: generateHeaders
        )
    }
}
