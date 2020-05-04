//
//  TUSSession.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

class TUSSession {
    var session: URLSession
    
    init() {
        //
        session = URLSession()
    }

    init(withDelegate delegate: URLSessionTaskDelegate) {
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: OperationQueue.main)
    }
    
    init(customConfiguration configuration: URLSessionConfiguration, andDelegate delegate: URLSessionTaskDelegate) {
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: OperationQueue.main)
    }
}
