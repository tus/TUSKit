import XCTest
@testable import TUSKit

final class FilesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        do {
            try Files.clearTUSDirectory()
        } catch {
            XCTFail("Could not clear dir \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try Files.clearTUSDirectory()
            try emptyCacheDir()
        } catch {
            XCTFail("Could not clear cache \(error)")
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
    
    func testCopyingFileFromURL() throws {
        let path = try Fixtures.makeFilePath()
        let url = try Files.copy(from: path, id: UUID())
        
        let _ = try Data(contentsOf: url)
        
        XCTFail("Implement id check, see if file gets id as path")
    }
    
    func testStoringData() throws {
        let url = try Files.store(data: Fixtures.loadData(), id: UUID())
        let _ = try Data(contentsOf: url)
        XCTFail("Implement id check, see if file gets id as path")
    }
    
    func testCanCopyMultipleFilesWithSameName() throws {
        // Make sure that a filename isn't reused and that you can upload the same file multiple times.
        let path = try Fixtures.makeFilePath()
        for _ in 0..<2 {
            let _ = try Files.copy(from: path, id: UUID())
        }
        
        XCTFail("Implement id check, see if file gets id as path")
    }
    
    func testCantStoreEmptyFile() throws {
        XCTFail("Implement me")
    }
    
    func testCantStoreEmptyData() throws {
        XCTFail("Implement me")
        
    }
    
    func testCheckMetadataHasWrongFilepath() throws {
        // TODO: Changing file url, and then storing it, and retrieving it, should have same fileurl as the metadata path again. E.g. if doc dir changed
        let metaData = UploadMetadata(id: UUID(), filePath: URL(string: "www.not-a-file-path.com")!, size: 300)
        XCTAssertThrowsError(try Files.encodeAndStore(metaData: metaData), "Expected Files to catch unknown file")
    }
    
    func testFilePathStaysInSyncWithMetaData() throws {
        // In this test we want to make sure that by retrieving metadata, its filepath property is the same dir as the metadata's directory.
        
        // Normally we write to the documents dir. But we explicitly are storing a file in a "wrong dir"
        // To see if retrieving metadata updates its directory.
        func writeDummyFileToCacheDir() throws -> URL {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let fileURL = cacheURL.appendingPathComponent("dummyfile.txt")

            let data = Data("Hello".utf8)
            try data.write(to: fileURL)
            return fileURL
        }
        
        func storeMetaData(filePath: URL) throws -> URL {
            // Manually store metadata, so we bypass the storing of files in a proper directory.
            // We are intentionally storing a file to cache dir (which is not expected).
            
            let metaData = UploadMetadata(id: UUID(), filePath: filePath, size: 5)
            
            let targetLocation = Files.targetDirectory.appendingPathComponent("dummyfile.plist")
            
            let encoder = PropertyListEncoder()
            let encodedData = try encoder.encode(metaData)
            try encodedData.write(to: targetLocation)
            return targetLocation
        }
        
        let url = try writeDummyFileToCacheDir()
        let targetLocation = try storeMetaData(filePath: url)
        let allMetadata = try Files.loadAllMetadata()
        
        guard !allMetadata.isEmpty else {
            XCTFail("Expected metadata to be retrieved")
            return
        }
        
        // Now we verify if retrieving metadata, will update the path to the same dir as the metadata.
        // Yes, the file isn't there (in this test), but in a real world scenario the file and metadata will be stored together. This test makes sure that if the documentsdir changes, we update the filepaths of metadata accordingly.
        
        let expectedLocation = targetLocation.deletingPathExtension()
        let retrievedMetaData = allMetadata[0]
        XCTAssertEqual(expectedLocation, retrievedMetaData.filePath)
    }
    
    func testMakeSureMetadataWithTooManyErrorsArentLoaded() {
        XCTFail("Implement me")
    }
   
}
