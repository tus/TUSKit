//
//  MockNetwork.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 22/09/2021.
//

import Foundation
@testable import TUSKit
// Gives us the ability to inspect and fake network calls.

// For consistency we don't complete a call on the same runloop. Could produce unrealistic results. For more info read about Zalgo https://blog.izs.me/2013/08/designing-apis-for-asynchrony/
// Improvement: Don't run network code until resume is called.
final class MockNetworkTask: NetworkTask {
    func resume() {
        
    }
    
    func cancel() {
        
    }
}

final class MockNetwork: Network {
    
    var receivedRequests = [URLRequest]()
    let uploadURL = URL(string: "https://tusd.tusdemo.net/files/3f934f6")!
    
    func dataTask(request: URLRequest, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        receivedRequests.append(request)
        DispatchQueue.main.async {
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 201,
                                           httpVersion: nil,
                                           headerFields:
                                            ["Location": self.uploadURL.absoluteString])!
            completion(.success((nil, response)))
        }
        return MockNetworkTask()
    }
    
    func uploadTask(request: URLRequest, data: Data, completion: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void) -> NetworkTask {
        receivedRequests.append(request)
        DispatchQueue.main.async {
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 201,
                                           httpVersion: nil,
                                           headerFields: [:])!
            completion(.success((nil, response)))
        }
        
        return MockNetworkTask()
    }
}

