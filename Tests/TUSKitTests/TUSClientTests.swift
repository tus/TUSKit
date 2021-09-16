import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here.

final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    
    override func setUp() {
        super.setUp()
        
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        client = TUSClient(config: TUSConfig(server: liveDemoPath))
    }

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
    
    func testPausing() {
        XCTFail("Implement me")
        // Test pausing before adding files
        // Probably it has no pause? Just start stop.
    }
    
    func testResuming() {
        XCTFail("Implement me")
    }
    
    func testDisablingPersistence() {
        XCTFail("Implement me")
        
        // Give people option to upload without storing to disk. Probably via config.
    }
    
    func testCantUploadEmptyFile() {
        XCTFail("Implement me")
    }
    
    func testCantUploadEmptyData() {
        XCTFail("Implement me")
    }
}
