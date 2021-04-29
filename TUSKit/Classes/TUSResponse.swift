//
//  TUSResponse.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public struct TUSResponse: Codable {
    
    public var message: String?
    // http status code that was eventually received
    public var errorCode: Int?
}
