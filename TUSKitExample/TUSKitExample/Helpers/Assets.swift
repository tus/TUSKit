//
//  Assets.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 14/07/23.
//

import SwiftUI

enum Icon: String {
    // Upload action button
    case resume = "play.circle"
    case pause  = "pause.circle"
    case trash  = "trash"
    case clear  = "xmark.circle"
    
    // Tab items
    case uploadFile = "square.and.arrow.up"
    case uploadFileFilled = "square.and.arrow.up.fill"
    case uploadList = "list.bullet"
    
    // Nav bar
    case options    = "ellipsis.circle"
    case checkmark  = "checkmark.circle"
    
    var color: Color {
        switch self {
            case .resume:
                return .blue
            case .pause, .clear:
                return .blue
            case .trash:
                return .red
            default:
                return .clear
        }
    }
}
