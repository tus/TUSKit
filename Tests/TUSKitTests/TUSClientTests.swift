import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here.

final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    
    override func setUp() {
        super.setUp()
        
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        relativeStoragePath = URL(string: "TUSTEST")!
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        client = TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: relativeStoragePath)
    }
    
    override func tearDown() {
        super.tearDown()
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
    
    func testMultipleInstancesDontClashWithFilesIfPathsAreDifferent() {
        // Make multiple instances, they shouldn't interfere with each other's files.
        // Already know to remove the Files. singleton dir
        XCTFail("Implement me")
    }
    
    func testIdsAreGivenAndReturnedWhenFinished() {
        XCTFail("Implement me")
        // Make sure id's that are given when uploading, are returned when uploads are finished
    }
    
    func testUploadIdsArePreservedBetweenSessions() {
        XCTFail("Implement me")
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
    }
    
    func testDeletingAllFiles() throws {
        try makeDirectoryIfNeeded(url: fullStoragePath)
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty, "Prerequisite for tests fails")
        
        let data = Data("abc".utf8)
        try data.write(to: fullStoragePath.appendingPathComponent("abc.txt"))
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertFalse(contents.isEmpty)
        try client.clearAllCache()
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
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
    
    func testMakeSureMetadataWithTooManyErrorsArentLoaded() {
        XCTFail("Implement me")
    }
    
    
}

private func makeDirectoryIfNeeded(url: URL) throws {
    let doesExist = FileManager.default.fileExists(atPath: url.path, isDirectory: nil)
    
    if !doesExist {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
