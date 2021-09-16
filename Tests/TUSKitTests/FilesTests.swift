import XCTest
@testable import TUSKit

final class FilesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try! Files.clearTUSDirectory()
    }
    
    override func tearDown() {
        try! Files.clearTUSDirectory()
    }
    
    func testCopyingFileFromURL() throws {
        let path = try Fixtures.makeFilePath()
        let url = try Files.copy(from: path)
        
        let _ = try Data(contentsOf: url)
    }
    
    func testStoringData() throws {
        let url = try Files.store(data: Fixtures.loadData())
        let _ = try Data(contentsOf: url)
    }
    
    func testCanCopyMultipleFilesWithSameName() throws {
        // Make sure that a filename isn't reused and that you can upload the same file multiple times.
        let path = try Fixtures.makeFilePath()
        for x in 0..<2 {
            let _ = try Files.copy(from: path)
        }
    }
    
    func testCantStoreEmptyFile() throws {
        XCTFail("Implement me")
    }
    
    func testCantStoreEmptyData() throws {
        XCTFail("Implement me")
    }
}
