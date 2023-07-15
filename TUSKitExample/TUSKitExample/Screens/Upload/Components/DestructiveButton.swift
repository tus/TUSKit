//
//  DestructiveButton.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 15/07/23.
//

import SwiftUI

// TODO: - Remove availability check once target is changed to iOS 15 and above
struct DestructiveButton: View {
    
    let title: String?
    let onTap: () -> Void
    
    var body: some View {
        if #available(iOS 15.0, *) {
            Button(role: .destructive) {
                onTap()
            } label: {
                if let title {
                    Text(title)
                }
                UploadActionImage(icon: .trash)
            }
        } else {
            Button {
                onTap()
            } label: {
                if let title {
                    Text(title)
                }
                UploadActionImage(icon: .trash)
            }
        }
    }
}
