import XCTest
@testable import TUSKit

final class DataTests: XCTestCase {
    
    func testChunking() {
        let str = "Who is a chunky monkey?"
        let data = Data(str.utf8)
        let chunkSize = 3
        let chars = Array(str)
        
        let strings = stride(from: 0, to: chars.count, by: chunkSize).map { index in
            String(chars[index..<Swift.min(index + chunkSize, chars.count)])
        }
        
        for (expectedString, chunk) in zip(strings, data.chunks(size: chunkSize)) {
            let string = String(data: chunk, encoding: .utf8)
            
            XCTAssertEqual(expectedString, string)
        }
    }
    
    func testLargeChunk() {
        let str = "Who is a chunky monkey?"
        let data = Data(str.utf8)
        let chunkSize = 300
        
        XCTAssertEqual(1, data.chunks(size: chunkSize).count)
    }
}
