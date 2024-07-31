//
//  NetworkTask.swift
//  TUSKit
//
//  Created by Donny Wals on 24/07/2024.
//

import Foundation

actor NetworkTask<Success: Sendable, SessionTask: URLSessionTask> {
    let urlsessionTask: SessionTask
    private let stream: AsyncThrowingStream<Success, any Error>
    private let continuation: AsyncThrowingStream<Success, any Error>.Continuation
    
    init(urlsessionTask: SessionTask) {
        self.urlsessionTask = urlsessionTask
        
        let (stream, continuation) = AsyncThrowingStream<Success, any Error>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }
    
    func getResult() async throws -> Success {
        for try await value in stream {
            return value
        }
        
        fatalError("Stream ended without producing a value...")
    }
    
    func sendResult(_ result: Result<Success, any Error>) {
        continuation.yield(with: result)
    }
}
