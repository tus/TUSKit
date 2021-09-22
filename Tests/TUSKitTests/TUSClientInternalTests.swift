//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 22/09/2021.
//

import XCTest
@testable import TUSKit

// Unlike TUSClientTests, we can do internal tests here. Separating it means we protect the public API in the other tests.
// Because we do have a testable import here, we allow for more control such as network behavior.

final class TUSClientInternalTests: XCTestCase {

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
        _ = try? client.clearAllCache()
    }
    
    override func tearDown() {
        super.tearDown()
        XCTAssertNoThrow(try client.clearAllCache())
    }
    
    func testClientCanHandleDirectoryStartingWithOrWithoutForwardSlash() {
        // Initialize tusclient with either "TUS" or "/TUS" and it should work
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsFollowRetryLimitAndAreUploadedAgain() {
        // Only for x amount of errors
        XCTFail("Implement me")
    }
    
    func testMakeSureErronousUploadsAreRetriedXTimes() {
        // Only retry error upload x times
        XCTFail("Implement me")
    }
    
    func testUploadingWithCustomHeaders() {
        // Make sure client adds custom headers
        XCTFail("Implement me")
    }

    func testClientDeletesFilesOnCompletion() {
        // If a file is done uploading (as said by status), but not yet deleted.
        // Then the file can be deleted right after fetching the status.
        XCTFail("Implement me")
    }
    
    func testDeleteUploadedFilesOnStartup() {
       XCTFail("Implement me")
    }
    
    
}
