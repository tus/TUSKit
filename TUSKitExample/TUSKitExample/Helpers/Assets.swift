//
//  Assets.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 14/07/23.
//

import Foundation
import SwiftUI

enum Icon: String {
    case resume = "play.circle"
    case pause  = "pause.circle"
    case trash  = "trash"
    case clear  = "xmark.circle"
    
    case uploadFile = "square.and.arrow.up"
    case uploadFileFilled = "square.and.arrow.up.fill"
    case uploadList = "list.bullet"
    
    case options    = "ellipsis.circle"
    case checkmark  = "checkmark.circle"
    
    var color: Color {
        switch self {
            case .resume:
                return .blue
            case .pause:
                return .blue
            case .trash:
                return TusColor.delete
            case .clear:
                return TusColor.remove
            default:
                return .clear
        }
    }
}

struct TusColor {
    static let uploaded: Color     = .green
    static let failed: Color       = .red
    static let uploading: Color    = .purple
    static let paused: Color       = .gray
    
    static let delete: Color       = .red
    static let remove: Color       = .blue
}
