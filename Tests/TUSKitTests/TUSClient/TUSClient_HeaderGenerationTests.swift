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

        relativeStoragePath = URL(string: "TUSHeaderTests")!

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
}
