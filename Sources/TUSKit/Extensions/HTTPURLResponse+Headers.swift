//
//  File.swift
//  
//
//  Created by Sai Raghu Varma Kallepalli on 11/07/23.
//

import Foundation

extension HTTPURLResponse {
    func extractHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        for header in allHeaderFields {
            let key1 = String(describing: header.key)
            let value1 = String(describing: header.value)
            headers[key1] = value1
        }
        return headers
    }
}
