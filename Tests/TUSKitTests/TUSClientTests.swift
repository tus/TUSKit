import XCTest
import TUSKit // ⚠️ No testable import. Make sure we test the public api here, and not against internals. If you want to test internals, see `TUSClientInternalTests`
final class TUSClientTests: XCTestCase {
    
    var client: TUSClient!
    var otherClient: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    
    override func setUp() {
        super.setUp()
        
        let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
        relativeStoragePath = URL(string: "TUSTEST")!
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
        clearDirectory(dir: fullStoragePath)
        
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        client = TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: relativeStoragePath, session: URLSession.init(configuration: configuration))
        
        tusDelegate = TUSMockDelegate()
        client.delegate = tusDelegate
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
        try client.clearAllCache()

        contents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)

        otherClientContents = try FileManager.default.contentsOfDirectory(at: otherLocation, includingPropertiesForKeys: nil)
        XCTAssert(!otherClientContents.isEmpty)
    }
    
    func testIdsAreGivenAndReturnedWhenFinished() {
        XCTFail("Implement me")
        // Make sure id's that are given when uploading, are returned when uploads are finished
    }
    
    func testUploadIdsArePreservedBetweenSessions() {
        XCTFail("Implement me")
        // Make sure that once id's are given, and then the tusclient restarts a session, it will still use the same id's
    }
    
    func testClearingCache() throws {
        
        try makeDirectoryIfNeeded(url: fullStoragePath)
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty, "Prerequisite for tests fails. Expected dir to be empty \(String(describing: fullStoragePath))")
        
        for _ in 0..<6 {
            try client.upload(data: Data("abcdef".utf8))
        }
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(!contents.isEmpty)
        
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

private func clearDirectory(dir: URL) {
    do {
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        for name in names
        {
            let path = "\(dir.path)/\(name)"
            try FileManager.default.removeItem(atPath: path)
        }
    } catch {
        print(error.localizedDescription)
    }
}
