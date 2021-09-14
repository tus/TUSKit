//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 14/09/2021.
//

import Foundation

extension Optional {
    
    /// Convenience method to throw an error if an optional is nil
    /// - Parameter willThrow: An error to throw if the optional is nil
    /// - Throws:The error that you pass to `willThrow`
    /// - Returns: A value if it's there. Otherwilse will throw an error
    func or(willThrow: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
        case .none:
            throw willThrow()
        case .some(let value):
            return value
        }
    }
}
