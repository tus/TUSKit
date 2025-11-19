import XCTest
import TUSKit

/// Tests around the upcoming header generation hook so that we can evolve the behaviour safely.
final class TUSClient_HeaderGenerationTests: XCTestCase {

    var client: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!

    override func setUp() {
        super.setUp()

        relativeStoragePath = URL(string: UUID().uuidString)!

        MockURLProtocol.reset()

        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)

        clearDirectory(dir: fullStoragePath)

        data = Data("abcdef".utf8)

        tusDelegate = TUSMockDelegate()
        prepareNetworkForSuccesfulUploads(data: data)
    }

    override func tearDown() {
        super.tearDown()
        clearDirectory(dir: fullStoragePath)
        client = nil
    }

    /// Verifies the generator receives exactly the caller supplied custom headers and the upload identifier for correlation.
    func testGenerateHeadersReceivesOnlyCallerSuppliedHeaders() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]

        let expectedHeaders = [
            "Authorization": "Bearer token",
            "X-Trace-ID": "trace-123",
        ]
        var receivedHeaders: [String: String]?
        var receivedRequestID: UUID?
        let generatorCalled = expectation(description: "Header generator called")

        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { requestID, headers, onHeadersGenerated in
                receivedRequestID = requestID
                receivedHeaders = headers
                onHeadersGenerated(headers)
                generatorCalled.fulfill()
            }
        )
        client.delegate = tusDelegate

        let uploadID = try client.upload(data: data, customHeaders: expectedHeaders)

        wait(for: [generatorCalled], timeout: 1)
        XCTAssertEqual(receivedHeaders, expectedHeaders)
        XCTAssertEqual(receivedRequestID, uploadID)
    }

    /// Verifies we don't bother clients when there are no custom headers to override.
    func testGenerateHeadersNotCalledWhenNoCustomHeaders() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]

        let generatorNotCalled = expectation(description: "Header generator should not be invoked")
        generatorNotCalled.isInverted = true

        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, _, onHeadersGenerated in
                generatorNotCalled.fulfill()
                onHeadersGenerated([:])
            }
        )
        client.delegate = tusDelegate

        XCTAssertNoThrow(try client.upload(data: data))
        wait(for: [generatorNotCalled], timeout: 0.5)
    }

    /// Ensures the generator receives the headers that were actually used on the previous request when retrying.
    func testGenerateHeadersReceivesLastAppliedValuesOnAutomaticRetry() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]

        prepareNetworkForSuccesfulUploads(data: data)
        prepareNetworkForFailingUploads()

        var receivedAuthorizationHeaders: [String] = []
        let generatorCalledTwice = expectation(description: "Header generator called twice")
        generatorCalledTwice.expectedFulfillmentCount = 2
        var trackedCalls = 0

        let uploadFailed = expectation(description: "Upload should fail after retries")
        tusDelegate.uploadFailedExpectation = uploadFailed

        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, headers, onHeadersGenerated in
                let current = headers["Authorization"] ?? ""
                receivedAuthorizationHeaders.append(current)
                let nextValue = current.isEmpty ? "Bearer mutated\(receivedAuthorizationHeaders.count)" : "\(current)-mutated\(receivedAuthorizationHeaders.count - 1)"
                onHeadersGenerated(["Authorization": nextValue])
                if trackedCalls < 2 {
                    generatorCalledTwice.fulfill()
                }
                trackedCalls += 1
            }
        )
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: ["Authorization": "Bearer original"])

        wait(for: [uploadFailed, generatorCalledTwice], timeout: 5)
        XCTAssertGreaterThanOrEqual(receivedAuthorizationHeaders.count, 2)
        XCTAssertEqual(receivedAuthorizationHeaders[0], "Bearer original")
        XCTAssertEqual(receivedAuthorizationHeaders[1], "Bearer original-mutated0")
    }

    /// Ensures resuming an upload reuses the previously applied headers.
    func testGenerateHeadersCalledWhenResumingUpload() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]

        prepareNetworkForSuccesfulUploads(data: data)

        let firstGeneratorCalled = expectation(description: "First header generator called")
        let uploadStarted = expectation(description: "Upload started before pausing")
        tusDelegate.startUploadExpectation = uploadStarted

        var firstFulfilled = false
        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, headers, onHeadersGenerated in
                onHeadersGenerated(["Authorization": "Bearer resume-mutated"])
                if !firstFulfilled {
                    firstFulfilled = true
                    firstGeneratorCalled.fulfill()
                }
            }
        )
        client.delegate = tusDelegate

        let uploadID = try client.upload(data: data, customHeaders: ["Authorization": "Bearer resume"])
        wait(for: [firstGeneratorCalled, uploadStarted], timeout: 5)
        client.stopAndCancelAll()

        MockURLProtocol.reset()
        prepareNetworkForSuccesfulStatusCall(data: data)
        prepareNetworkForSuccesfulUploads(data: data)

        tusDelegate = TUSMockDelegate()
        let finishExpectation = expectation(description: "Upload should finish after resume")
        tusDelegate.finishUploadExpectation = finishExpectation

        var resumedHeaders: [String] = []
        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, headers, onHeadersGenerated in
                resumedHeaders.append(headers["Authorization"] ?? "")
                onHeadersGenerated(headers)
            }
        )
        client.delegate = tusDelegate

        let resumedUploads = client.start().map(\.0)
        XCTAssertTrue(resumedUploads.contains(uploadID))
        wait(for: [finishExpectation], timeout: 5)
        XCTAssertFalse(resumedHeaders.isEmpty)
        XCTAssertEqual(resumedHeaders.first, "Bearer resume-mutated")
    }

    /// Ensures uploads wait for asynchronous header generation before proceeding.
    func testGenerateHeadersSupportsAsynchronousCompletion() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        prepareNetworkForSuccesfulUploads(data: data)

        let asyncExpectation = expectation(description: "Async header generator invoked")
        asyncExpectation.expectedFulfillmentCount = 2
        let finishExpectation = expectation(description: "Upload finished")
        tusDelegate.finishUploadExpectation = finishExpectation

        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, headers, onHeadersGenerated in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    asyncExpectation.fulfill()
                    onHeadersGenerated(headers.merging(["Authorization": "Bearer async"]) { _, new in new })
                }
            }
        )
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: ["Authorization": "Bearer original"])
        wait(for: [asyncExpectation, finishExpectation], timeout: 5)
    }

    /// Ensures the generator only receives caller-supplied headers during upload creation.
    func testGenerateHeadersReceivesOnlyCustomHeadersDuringCreate() throws {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        prepareNetworkForSuccesfulUploads(data: data)

        let customHeaders = ["Authorization": "Bearer foo", "X-Trace": "123"]
        var observedHeaders: [[String: String]] = []
        let createGeneratorCalled = expectation(description: "Header generator called during create")

        var createInvocationRecorded = false
        client = try TUSClient(
            server: URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier: "TEST",
            sessionConfiguration: configuration,
            storageDirectory: relativeStoragePath,
            supportedExtensions: [.creation],
            generateHeaders: { _, headers, onHeadersGenerated in
                if !createInvocationRecorded {
                    observedHeaders.append(headers)
                    createInvocationRecorded = true
                    createGeneratorCalled.fulfill()
                }
                onHeadersGenerated(headers)
            }
        )
        tusDelegate.finishUploadExpectation = expectation(description: "Upload finished")
        client.delegate = tusDelegate

        _ = try client.upload(data: data, customHeaders: customHeaders)
        wait(for: [createGeneratorCalled, tusDelegate.finishUploadExpectation!], timeout: 5)

        XCTAssertEqual(observedHeaders.first, customHeaders)
    }
}
