//
//  PausedRowView.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 15/07/23.
//

import SwiftUI

struct PausedRowView: View {
    @EnvironmentObject var tusWrapper: TUSWrapper
   
    let key: UUID
    let bytesUploaded: Int
    let totalBytes: Int
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                UploadStatusIndicator(color: TusColor.paused)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(UploadCategory.paused.title)")
                            .foregroundColor(TusColor.paused)
                            .font(.subheadline)
                            .bold()
                        
                        Text("(\(bytesUploaded) / \(totalBytes))")
                            .foregroundColor(TusColor.paused)
                            .font(.caption)
                    }
                    
                    Text("ID - \(key)")
                        .font(.caption)
                }
                
                Spacer()
                
                uploadingActionsView(withTitle: false)
            }
            
            ProgressView(value: Float(bytesUploaded), total: Float(totalBytes))
                .accentColor(.gray)
                .padding(.bottom, 2)
        }
        .rowPadding()
        .contextMenu {
            uploadingActionsView(withTitle: true)
        }
    }
    
    @ViewBuilder
    func uploadingActionsView(withTitle: Bool) -> some View {
        Button {
            tusWrapper.resumeUpload(id: key)
        } label: {
            if withTitle {
                Text("Resume")
            }
            UploadActionImage(icon: .resume)
        }
        
        DestructiveButton(title: withTitle ? "Remove" : nil) {
            tusWrapper.clearUpload(id: key)
        }
    }
}
