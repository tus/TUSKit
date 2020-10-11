//
//  UploadTest.swift
//  TUSKit_Tests
//
//  Created by Mark Robert Masterson on 10/10/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import XCTest
import TUSKit

class UploadTest: XCTestCase, TUSDelegate {
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
        
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
    }
    
    func TUSSuccess(forUpload upload: TUSUpload) {
        //
        uploadOne = upload
        uploadExpectation.fulfill()
    }
    
    func TUSFailure(forUpload upload: TUSUpload?, withResponse response: TUSResponse?, andError error: Error?) {
        //
    }
    
    private var uploadExpectation: XCTestExpectation!
    var uploadOne: TUSUpload?
    var uploadTwo: TUSUpload?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        uploadExpectation = expectation(description: "Success")

        var config = TUSConfig(withUploadURLString: "https://tusd.tusdemo.net/files")
        config.logLevel = .All
        TUSClient.setup(with: config)
        TUSClient.shared.delegate = self
        let testBundle = Bundle.main
        guard let fileURL = testBundle.url(forResource: "memeCat", withExtension: "jpg")
        else { fatalError() }
        
        uploadOne = TUSUpload(withId: "TestFile", andFilePathURL: fileURL, andFileType: "jpg")
        uploadTwo = TUSUpload(withId: "TestFile", andData: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!, andFileType: "jpg")

        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testDataupload() throws {
        TUSClient.shared.createOrResume(forUpload: uploadTwo!)
        waitForExpectations(timeout: 100)
        XCTAssertNotNil(uploadOne?.uploadLocationURL)
    }

    func testFileUpload() throws {
               TUSClient.shared.createOrResume(forUpload: uploadOne!)
               waitForExpectations(timeout: 100)
               XCTAssertNotNil(uploadOne?.uploadLocationURL)
    }

}
