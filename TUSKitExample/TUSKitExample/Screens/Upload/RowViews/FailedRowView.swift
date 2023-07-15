//
//  FailedRowView.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 15/07/23.
//

import SwiftUI

struct FailedRowView: View {
    
    @EnvironmentObject var tusWrapper: TUSWrapper
   
    let key: UUID
    let error: Error
    
    var body: some View {
        HStack(spacing: 8) {
            UploadStatusIndicator(color: TusColor.failed)
            VStack(alignment: .leading) {
                Text(UploadCategory.failed.title)
                    .foregroundColor(TusColor.failed)
                    .font(.subheadline)
                    .bold()
                
                Text("ID - \(key)")
                    .font(.caption)
                Text("Error - \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.gray)
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
        DestructiveButton(title: withTitle ? "Remove" : nil) {
            tusWrapper.clearUpload(id: key)
        }
    }
}
