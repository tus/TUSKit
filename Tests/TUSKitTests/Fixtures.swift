import XCTest

struct Fixtures {
    
    static let chunkSize: Int = 500 * 1024
    
    static func makeFilePath() throws -> URL {
        // Loading resources normally gives an error on github actions
        
        // Originally, you can load like this:
//        let bundle = Bundle.module
//        let path = try XCTUnwrap(bundle.path(forResource: "memeCat", ofType: "jpg"))
//        return try XCTUnwrap(URL(string: path))
        // But the CI doesn't accept that.
        // Instead, we'll look up the current file and load from there.
        
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/memeCat.jpg")
        
        return resourceURL
    }
    
    static func loadData() throws -> Data {
        // We need to prepend with file:// so Data can load it.
        let prefixedPath = try  "file://" + makeFilePath().absoluteString
        return try Data(contentsOf: URL(string:prefixedPath)!)
    }
    
    
    /// Make a Data file larger than the chunk size
    /// - Returns: Data
    static func makeLargeData() -> Data {
        return Data(repeatElement(1, count: chunkSize + 1))
    }
    
}
