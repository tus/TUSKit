import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here.

final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    
    override func setUp() {
        super.setUp()
        
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        client = TUSClient(config: TUSConfig(server: liveDemoPath), storageDirectory: nil)
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
    
    func testStatusDeletesFileIfCompleted() {
        // If a file is done uploading (as said by status), but not yet deleted.
        // Then the file can be deleted right after fetching the status.
        XCTFail("Implement me")
    }
    
    func testDeleteUploadedFilesOnStartup() {
       XCTFail("Implement me")
    }
    
    func testIdsAreGivenAndReturnedWhenFinished() {
        XCTFail("Implement me")
        // Make sure id's that are given when uploading, are returned when uploads are finished
    }
    
    func testIdsArePreservedBetweenSessions() {
        XCTFail("Implement me")
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
    }
    
    func testDeletingFile() {
        XCTFail("Implement me")
    }
    
    func testDeletingAllFiles() {
        XCTFail("Implement me")
    }
    
    func testMakeSureFileIdIsSameAsStoredId() {
//         A file is stored under a UUID, this must be the same as the metadata's id
        XCTFail("Implement me")
    }
    
    func testClientCanHandleDirectoryStartingWithOrWithoutForwardSlash() {
        // Initialize tusclient with either "TUS" or "/TUS" and it should work
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsAreNotUploadedAgain() {
        // Only for x amount of errors
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsAreRetriedXTimes() {
        // Only retry error upload x times
        XCTFail("Implement me")
    }
}

