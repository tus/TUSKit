//
//  ProcessInfo.swift
//  
//
//  Created by MartinLau on 06/02/2023.
//

import Foundation

#if os(macOS)
extension ProcessInfo {
    var inSandboxContainer: Bool {
        guard let _ = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] else {
            return false
        }
        return true
    }
}
#endif
