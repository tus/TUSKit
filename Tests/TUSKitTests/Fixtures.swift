import XCTest

struct Fixtures {
    static func makeFilePath() throws -> URL {
        let bundle = Bundle.module
        
        let path = try XCTUnwrap(bundle.path(forResource: "memeCat", ofType: "jpg"))
        
        return try XCTUnwrap(URL(string: path))
    }
    
    static func loadData() throws -> Data {
        // We need to prepend with file:// so Data can load it.
        let prefixedPath = try  "file://" + makeFilePath().absoluteString
        return try Data(contentsOf: URL(string:prefixedPath)!)
    }
    
}
