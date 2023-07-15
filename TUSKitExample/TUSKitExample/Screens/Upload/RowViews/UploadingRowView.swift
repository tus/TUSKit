//
//  UploadingRowView.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 15/07/23.
//

import SwiftUI

struct UploadingRowView: View {
    
    @EnvironmentObject var tusWrapper: TUSWrapper
   
    let key: UUID
    let bytesUploaded: Int
    let totalBytes: Int
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                UploadStatusIndicator(color: TusColor.uploading)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(UploadCategory.uploading.title)")
                            .foregroundColor(TusColor.uploading)
                            .font(.subheadline)
                        .bold()
                        
                        Text("(\(bytesUploaded) / \(totalBytes))")
                            .foregroundColor(TusColor.uploading)
                            .font(.caption)
                    }
                    Text("ID - \(key)")
                        .font(.caption)
                }
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(x: 0.8, y: 0.8)
                
                uploadingActionsView(withTitle: false)
            }
            
            ProgressView(value: Float(bytesUploaded), total: Float(totalBytes))
                .accentColor(TusColor.uploading)
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
            tusWrapper.pauseUpload(id: key)
        } label: {
            if withTitle {
                Text("Pause")
            }
            UploadActionImage(icon: .pause)
        }
        
        DestructiveButton(title: withTitle ? "Remove" : nil) {
            tusWrapper.clearUpload(id: key)
        }
    }
}
