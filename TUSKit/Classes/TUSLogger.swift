//
//  TUSLogger.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/18/20.
//

import UIKit

internal class TUSLogger: NSObject {
    
    var enabled: Bool
    
    init(_ enabled: Bool) {
        self.enabled = enabled
    }
    
    func log(_ string: String) {
        if enabled {
            print(String(format: "TUSKit: %@", string))
        }
    }

}
