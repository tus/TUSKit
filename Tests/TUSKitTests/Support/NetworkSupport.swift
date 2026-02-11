import Foundation
import XCTest
@testable import TUSKit

/// Server gives inappropriorate offsets
/// - Parameter data: Data to upload
func prepareNetworkForWrongOffset(data: Data, testID: String? = nil) {
    MockURLProtocol.prepareResponse(for: "POST", testID: testID) { _ in
        MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
    }
    
    // Mimick chunk uploading with offsets
    MockURLProtocol.prepareResponse(for: "PATCH", testID: testID) { headers in
        
        guard let headers = headers,
              let strOffset = headers["Upload-Offset"],
              let offset = Int(strOffset),
              let strContentLength = headers["Content-Length"],
              let contentLength = Int(strContentLength) else {
                  let error = "Did not receive expected Upload-Offset and Content-Length in headers"
                  XCTFail(error)
                  fatalError(error)
              }
        
        let newOffset = offset + contentLength - 1 // 1 offset too low. Trying to trigger potential inifnite upload loop. Which the client should handle, of course.
        return MockURLProtocol.Response(status: 200, headers: ["Upload-Offset": String(newOffset)], data: nil)
    }
}

func prepareNetworkForSuccesfulUploads(data: Data, lowerCasedKeysInResponses: Bool = false, testID: String? = nil) {
    MockURLProtocol.prepareResponse(for: "POST", testID: testID) { _ in
        let key: String
        if lowerCasedKeysInResponses {
            key = "location"
        } else {
            key = "Location"
        }
        return MockURLProtocol.Response(status: 200, headers: [key: "www.somefakelocation.com"], data: nil)
    }
    
    // Mimick chunk uploading with offsets
    MockURLProtocol.prepareResponse(for: "PATCH", testID: testID) { headers in
        
        guard let headers = headers,
              let strOffset = headers["Upload-Offset"],
              let offset = Int(strOffset),
              let strContentLength = headers["Content-Length"],
              let contentLength = Int(strContentLength) else {
                  let error = "Did not receive expected Upload-Offset and Content-Length in headers"
                  XCTFail(error)
                  fatalError(error)
              }
        
        let newOffset = offset + contentLength
        
        let key: String
        if lowerCasedKeysInResponses {
            key = "upload-offset"
        } else {
            key = "Upload-Offset"
        }
        return MockURLProtocol.Response(status: 200, headers: [key: String(newOffset)], data: nil)
    }
    
}

func prepareNetworkForErronousResponses(testID: String? = nil) {
    MockURLProtocol.prepareResponse(for: "POST", testID: testID) { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
    MockURLProtocol.prepareResponse(for: "PATCH", testID: testID) { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
    MockURLProtocol.prepareResponse(for: "HEAD", testID: testID) { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
}

func prepareNetworkForSuccesfulStatusCall(data: Data, testID: String? = nil) {
    MockURLProtocol.prepareResponse(for: "HEAD", testID: testID) { _ in
        MockURLProtocol.Response(status: 200, headers: ["Upload-Length": String(data.count),
                                                        "Upload-Offset": "0"], data: nil)
    }
}

/// Create call can still succeed. This is useful for triggering a status call.
func prepareNetworkForFailingUploads(testID: String? = nil) {
    // Upload means patch. Letting that fail.
    MockURLProtocol.prepareResponse(for: "PATCH", testID: testID) { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
}

func resetReceivedRequests(testID: String? = nil) {
    MockURLProtocol.clearReceivedRequests(testID: testID)
}
