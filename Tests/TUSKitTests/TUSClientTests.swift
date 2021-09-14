import XCTest
@testable import TUSKit

final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    
    override func setUp() {
        super.setUp()
        
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        client = TUSClient(config: TUSConfig(server: liveDemoPath))
    }

    func testUploadingNonExistentFile() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("thisfiledoesntexist.jpg")
        XCTAssertThrowsError(try client.uploadFileAt(filePath: fileURL), "If a file doesn't exist, the client should throw a message right when an uploadTask is triggered")
    }
    
    func testUploadingExistingFile() {
        try XCTAssertNoThrow(client.uploadFileAt(filePath: makeFilePath()), "TUSClient should accept files that exist")
    }
    
    func testUploadingValidData() throws {
        XCTAssertNoThrow(try client.upload(data: loadData()))
    }
    
    func testPausing() {
        XCTFail("Implement me")
        // Test pausing before adding files
        // Probably it has no pause? Just start stop.
    }
    
    func testResuming() {
        XCTFail("Implement me")
    }
    
    private func makeFilePath() throws -> URL {
        let bundle = Bundle.module
        
        let path = try XCTUnwrap(bundle.path(forResource: "memeCat", ofType: "jpg"))
        
        return try XCTUnwrap(URL(string: path))
    }
    
    private func loadData() throws -> Data {
        // We need to prepend with file:// so Data can load it.
        let prefixedPath = try  "file://" + makeFilePath().absoluteString
        return try Data(contentsOf: URL(string:prefixedPath)!)
    }
}
