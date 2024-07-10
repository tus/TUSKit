import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. Please look at TUSClientInternalTests if you want a testable import version.
final class TUSClient_CustomHeadersTests: XCTestCase {
    
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
    
    func testUploadingWithCustomHeadersForFiles() async throws {
        // Make sure client adds custom headers
        
        // Expected values
        let key = "Authorization"
        let value = "Bearer [token]"
        let customHeaders = [key: value]
        
        // Store file
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Store file in cache
        func storeFileInDocumentsDir() throws -> URL {
            let targetLocation = documentDir.appendingPathComponent("myfile.txt")
            try data.write(to: targetLocation)
            return targetLocation
        }
        
        let location = try storeFileInDocumentsDir()
        
        let startedExpectation = expectation(description: "Waiting for uploads to start")
        tusDelegate.startUploadExpectation = startedExpectation
        
        try await client.uploadFileAt(filePath: location, customHeaders: customHeaders)
        await fulfillment(of: [startedExpectation], timeout: 5)
        
        // Validate
        let createRequests = MockURLProtocol.receivedRequests.filter { $0.httpMethod == "POST" }
        
        for request in createRequests {
            let headers = try XCTUnwrap(request.allHTTPHeaderFields)
            XCTAssert(headers[key] == value, "Expected custom header '\(key)' to exist on headers with value: '\(value)'")
        }
    }
     

}
