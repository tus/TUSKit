//
//  TUSLogger.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/18/20.
//

import UIKit

internal class TUSLogger: NSObject {
    
    var enabled: Bool
    
    init(withLevel level: TUSLogLevel ,_ enabled: Bool) {
        self.enabled = enabled
    }
    
    func log(forLevel level: TUSLogLevel ,withMessage string: String) {
        if enabled {
            print(String(format: "TUSKit: %@", string))
        }
    }

}
