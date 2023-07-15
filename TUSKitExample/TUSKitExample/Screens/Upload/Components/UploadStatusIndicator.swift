//
//  UploadStatusIndicator.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 14/07/23.
//

import SwiftUI

struct UploadStatusIndicator: View {
    
    let color: Color
    let width: CGFloat = 5
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: width/2, style: .continuous)
                .foregroundColor(color)
                .frame(width: width)
        }
    }
}

struct UploadStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        UploadStatusIndicator(color: .gray)
    }
}
