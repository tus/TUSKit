//
//  UploadedRowView.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 15/07/23.
//

import SwiftUI

struct UploadedRowView: View {
    
    @EnvironmentObject var tusWrapper: TUSWrapper
   
    let key: UUID
    let url: URL
    
    var body: some View {
        HStack(spacing: 8) {
            UploadStatusIndicator(color: TusColor.uploaded)
            
            VStack(alignment: .leading) {
                Text(UploadCategory.uploaded.title)
                    .foregroundColor(TusColor.uploaded)
                    .font(.subheadline)
                    .bold()
                
                Text("ID - \(key)")
                    .font(.caption)
                
                Link("Uploaded link", destination: url)
                    .font(.caption2)
                
                Spacer()
            }
            
            Spacer()
            
            ActionsView(withTitle: false)
        }
        .rowPadding()
        .contextMenu {
            ActionsView(withTitle: true)
        }
    }
    
    @ViewBuilder
    func ActionsView(withTitle: Bool) -> some View {
        Button {
            tusWrapper.removeUpload(id: key)
        } label: {
            if withTitle {
                Text("Clear")
            }
            UploadActionImage(icon: .clear)
        }
    }
}
