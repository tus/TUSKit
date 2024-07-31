import Foundation
import XCTest
@testable import TUSKit

/// Server gives inappropriorate offsets
/// - Parameter data: Data to upload
func prepareNetworkForWrongOffset(data: Data) {
    MockURLProtocol.prepareResponse(for: "POST") { _ in
        MockURLProtocol.Response(status: 200, headers: ["Location": "www.somefakelocation.com"], data: nil)
    }
    
    // Mimick chunk uploading with offsets
    MockURLProtocol.prepareResponse(for: "PATCH") { headers in
        
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

func prepareNetworkForSuccesfulUploads(data: Data, lowerCasedKeysInResponses: Bool = false) {
    print("prepareing for succesful upload")
    MockURLProtocol.prepareResponse(for: "POST") { _ in
        print("returning a response for post")
        let key: String
        if lowerCasedKeysInResponses {
            key = "location"
        } else {
            key = "Location"
        }
        return MockURLProtocol.Response(status: 200, headers: [key: "www.somefakelocation.com"], data: nil)
    }
    
    print("prepareing for succesful patch")
    // Mimick chunk uploading with offsets
    MockURLProtocol.prepareResponse(for: "PATCH") { headers in
        print("returning a response for patch")
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

func prepareNetworkForErronousResponses() {
    MockURLProtocol.prepareResponse(for: "POST") { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
    MockURLProtocol.prepareResponse(for: "PATCH") { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
    MockURLProtocol.prepareResponse(for: "HEAD") { _ in
        MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
}

func prepareNetworkForSuccesfulStatusCall(data: Data) {
    print("Network prepared for successful status")
    MockURLProtocol.prepareResponse(for: "HEAD") { _ in
        print("Status will be returned")
        return MockURLProtocol.Response(status: 200, headers: ["Upload-Length": String(data.count),
                                                        "Upload-Offset": "0"], data: nil)
    }
}

/// Create call can still succeed. This is useful for triggering a status call.
func prepareNetworkForFailingUploads() {
    print("Network prepared for failure")
    // Upload means patch. Letting that fail.
    MockURLProtocol.prepareResponse(for: "PATCH") { _ in
        print("Error will be returned")
        return MockURLProtocol.Response(status: 401, headers: [:], data: nil)
    }
}

func resetReceivedRequests() {
    MockURLProtocol.receivedRequests = []
}
