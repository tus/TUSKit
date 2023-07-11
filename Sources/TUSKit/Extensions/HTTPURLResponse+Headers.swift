//
//  HTTPURLResponse+Headers.swift
//  
//
//  Created by Sai Raghu Varma Kallepalli on 11/07/23.
//

import Foundation

extension HTTPURLResponse {
    func extractHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        allHeaderFields.forEach { key, value in
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }
}
