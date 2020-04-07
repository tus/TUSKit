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
        session = URLSession(configuration: .default)
    }
    
    init(customConfiguration configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration)
    }
}
