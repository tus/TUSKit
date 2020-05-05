//
//  HTTPURLResponse+allHeadersUpper.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 5/5/20.
//

import Foundation

extension HTTPURLResponse {
    
    func allHeaderFieldsUpper() -> Dictionary<String, String> {
        var newHeaders = Dictionary<String, String>()
        for item in self.allHeaderFields {
            let key = item.key as! String
            newHeaders[key.uppercased()] = (item.value as! String)
        }
        return newHeaders
    }
    
}
