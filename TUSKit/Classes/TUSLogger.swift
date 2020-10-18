//
//  TUSLogger.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/18/20.
//

import Foundation

internal class TUSLogger: NSObject {
    
    var enabled: Bool
    var currentLevel: TUSLogLevel?
    
    init(withLevel level: TUSLogLevel ,_ enabled: Bool) {
        self.enabled = enabled
        currentLevel = level
    }
    
    func log(forLevel level: TUSLogLevel ,withMessage string: String) {
        if enabled {
            if (level.rawValue <= currentLevel!.rawValue) {
                print(String(format: "TUSKit: %@", string))
            }
        }
    }

}
