import XCTest
@testable import TUSKit

final class FilesTests: XCTestCase {

    var files: Files!
    override func setUp() {
        super.setUp()
        
        files = Files(storageDirectory: URL(string: "TUS")!)
        do {
            try files.clearCacheInStorageDirectory()
        } catch {
            XCTFail("Could not clear dir \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try files.clearCacheInStorageDirectory()
            try emptyCacheDir()
        } catch {
//            XCTFail("Could not clear cache \(error)")
        }
    }
    
    private func emptyCacheDir() throws {
        
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        guard FileManager.default.fileExists(atPath: cacheDirectory.path, isDirectory: nil) else {
            return
        }
        
        for file in try FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(atPath: cacheDirectory.appendingPathComponent(file).path)
        }

    }
    
    func testInitializers() {
        func removeTrailingSlash(url: URL) -> String {
            if url.absoluteString.last == "/" {
                return String(url.absoluteString.dropLast())
            } else {
                return url.absoluteString
            }
        }
            
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let values = [
            (URL(string: "ABC")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "/ABC")!, documentsDirectory.appendingPathComponent("ABC")),
            (URL(string: "ABC/ZXC")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (URL(string: "/ABC/ZXC")!, documentsDirectory.appendingPathComponent("ABC/ZXC")),
            (nil, documentsDirectory.appendingPathComponent("TUS")),
            (cacheDirectory.appendingPathComponent("TEST"), cacheDirectory.appendingPathComponent("TEST"))
            ]
        
        for (url, expectedPath) in values {
            let files = Files(storageDirectory: url)
            
            // Depending on the OS, there might be trailing slashes at the end of the path, that's okay.
            let trimmedExpectedPath = removeTrailingSlash(url: expectedPath)
            let trimmedPath = removeTrailingSlash(url: files.storageDirectory)
            
            XCTAssertEqual(trimmedPath, trimmedExpectedPath)
        }
    }
    
    func testCopyingFileFromURL() throws {
        let path = try Fixtures.makeFilePath()
        let id = UUID()
        let url = try files.copy(from: path, id: id)
        
        XCTAssert(url.lastPathComponent.contains(id.uuidString), "Expected path to contain id")
        
        let _ = try Data(contentsOf: url)
    }
    
    func testStoringData() throws {
        let id = UUID()
        let url = try files.store(data: Fixtures.loadData(), id: id)
        XCTAssert(url.lastPathComponent.contains(id.uuidString), "Expected path to contain id")
        let _ = try Data(contentsOf: url)
    }
    
    func testCanCopyMultipleFilesWithSameName() throws {
        // Make sure that a filename isn't reused and that you can upload the same file multiple times.
        let path = try Fixtures.makeFilePath()
        let expectedIds = (0..<2).map { _ in UUID() }
        let ids = try expectedIds.map { id in
            try files.copy(from: path, id: id)
        }
        
        XCTAssertEqual(Set(ids).count,ids.count, "Expected unique ids for all fiels")
    }
    
    func testCantSaveMultipleFilesWithSameId() throws {
        let id = UUID()
        
        let path = try Fixtures.makeFilePath()
        
        try files.copy(from: path, id: id)
        XCTAssertThrowsError(try files.copy(from: path, id: id))
    }
    
    func testCantStoreEmptyData() throws {
        XCTAssertThrowsError(try files.store(data: Data(), id: UUID()))
    }
    
    func testCheckMetadataHasWrongFilepath() throws {
        // TODO: Changing file url, and then storing it, and retrieving it, should have same fileurl as the metadata path again. E.g. if doc dir changed
        let metaData = UploadMetadata(id: UUID(), filePath: URL(string: "abc")!, uploadURL: URL(string: "www.not-a-file-path.com")!, size: 300)
        XCTAssertThrowsError(try files.encodeAndStore(metaData: metaData), "Expected Files to catch unknown file")
    }
    
    func testFilePathStaysInSyncWithMetaData() throws {
        // In this test we want to make sure that by retrieving metadata, its filepath property is the same dir as the metadata's directory.
        
        // Normally we write to the documents dir. But we explicitly are storing a file in a "wrong dir"
        // To see if retrieving metadata updates its directory.
        func writeDummyFileToCacheDir() throws -> URL {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let fileURL = cacheURL.appendingPathComponent("dummyfile.txt")
            return fileURL
        }
        
        func storeMetaData(filePath: URL) throws -> URL {
            // Manually store metadata, so we bypass the storing of files in a proper directory.
            // We are intentionally storing a file to cache dir (which is not expected).
            // But we store the metadata in the files' storagedirectory
            
            let metaData = UploadMetadata(id: UUID(), filePath: filePath, uploadURL: URL(string: "www.tus.io")!, size: 5)
            
            let targetLocation = files.storageDirectory.appendingPathComponent(filePath.lastPathComponent).appendingPathExtension("plist")
            
            let encoder = PropertyListEncoder()
            let encodedData = try encoder.encode(metaData)
            try encodedData.write(to: targetLocation)
            return targetLocation
        }
        
        let fileLocation = try writeDummyFileToCacheDir()
        let targetLocation = try storeMetaData(filePath: fileLocation)
        let allMetadata = try files.loadAllMetadata()
        
        guard !allMetadata.isEmpty else {
            XCTFail("Expected metadata to be retrieved")
            return
        }
        
        // Now we verify if retrieving metadata, will update the path to the same dir as the metadata.
        // Yes, the file isn't there (in this test, because we store it in the wrong dir), but in a real world scenario the file and metadata will be stored together. This test makes sure that if the documentsdir changes, we update the filepaths of metadata accordingly.
        
        let expectedLocation = targetLocation.deletingPathExtension()
        let retrievedMetaData = allMetadata[0]
        XCTAssertEqual(expectedLocation, retrievedMetaData.filePath)
        
        // Clean up metadata. Doing it here because normally cleaning up metadata also cleans up a file. But we don't have a file to clean up.
        try FileManager.default.removeItem(at: targetLocation)
    }
    
    func testMakeSureFileIdIsSameAsStoredName() throws {
//         A file is stored under a UUID, this must be the same as the metadata's id
        let id = UUID()
        let url = try files.store(data: Data("abc".utf8), id: id)
        XCTAssertEqual(id.uuidString, url.lastPathComponent)
        XCTAssert(FileManager.default.fileExists(atPath: url.path))
    }
   
}
