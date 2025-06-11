//
//  ProgressRowView.swift
//  TUSKitExample
//
//  Created by Sai Raghu Varma Kallepalli on 23/07/23.
//

import SwiftUI

struct ProgressRowView: View {
    
    @EnvironmentObject var tusWrapper: TUSWrapper
   
    let key: UUID
    let bytesUploaded: Int
    let totalBytes: Int
    
    let category: UploadListCategory
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                UploadStatusIndicator(color: category.color)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(category.title)
                            .foregroundColor(category.color)
                            .font(.subheadline)
                            .bold()
                        
                        Text("(\(bytesUploaded) / \(totalBytes))")
                            .foregroundColor(category.color)
                            .font(.caption)
                    }
                    
                    Text("ID - \(key)")
                        .font(.caption)
                }
                
                Spacer()
                
                if category == .uploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(x: 0.8, y: 0.8)
                }
                
                ActionsView(showTitle: false)
            }
            
            ProgressView(value: Float(bytesUploaded), total: Float(totalBytes))
                .accentColor(category.color)
                .padding(.bottom, 2)
        }
        .rowPadding()
        .contextMenu {
            ActionsView(showTitle: true)
        }
    }
    
    
    @ViewBuilder
    private func ActionsView(showTitle: Bool) -> some View {
        if category == .uploading {
            uploadingActionsView(showTitle: showTitle)
        } else {
            pausedActionsView(showTitle: showTitle)
        }
    }
    
    @ViewBuilder
    private func pausedActionsView(showTitle: Bool) -> some View {
        Button {
            tusWrapper.resumeUpload(id: key)
        } label: {
            if showTitle {
                Text("Resume")
            }
            UploadActionImage(icon: .resume)
        }
        
        DestructiveButton(title: showTitle ? "Remove" : nil) {
            tusWrapper.clearUpload(id: key)
        }
    }
    
    @ViewBuilder
    private func uploadingActionsView(showTitle: Bool) -> some View {
        Button {
            tusWrapper.pauseUpload(id: key)
        } label: {
            if showTitle {
                Text("Pause")
            }
            UploadActionImage(icon: .pause)
        }
        
        DestructiveButton(title: showTitle ? "Remove" : nil) {
            tusWrapper.clearUpload(id: key)
        }
    }
}
