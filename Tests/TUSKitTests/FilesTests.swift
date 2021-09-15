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
    
}
