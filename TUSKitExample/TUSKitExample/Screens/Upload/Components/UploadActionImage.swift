//
//  UploadActionImage.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 14/07/23.
//

import SwiftUI

struct UploadActionImage: View {
    
    let icon: Icon
    
    var body: some View {
        Image(systemName: icon.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundColor(icon.color)
    }
}
