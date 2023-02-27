//
//  UploadsView.swift
//  TUSKitExample
//
//  Created by Donny Wals on 27/02/2023.
//

import Foundation
import SwiftUI
import TUSKit

struct UploadsView: View {
    @ObservedObject var tusWrapper: TUSWrapper
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(Array(tusWrapper.uploads), id: \.key) { idx in
                    switch idx.value {
                    case .uploading(let bytesUploaded, let totalBytes):
                        HStack(spacing: 8) {
                            Button(action: {
                                tusWrapper.pauseUpload(id: idx.key)
                            }, label: {
                                Image(systemName: "playpause.fill")
                            })
                            
                            Button(action: {
                                tusWrapper.clearUpload(id: idx.key)
                            }, label: {
                                Image(systemName: "trash.fill")
                            })
                            
                            Text("Item \(idx.key) uploading - \(bytesUploaded) / \(totalBytes)")
                            
                            Spacer()
                        }
                    case .paused(let bytesUploaded, let totalBytes):
                        HStack(spacing: 8) {
                            Button(action: {
                                tusWrapper.resumeUpload(id: idx.key)
                            }, label: {
                                Image(systemName: "playpause.fill")
                            })
                            
                            Button(action: {
                                tusWrapper.clearUpload(id: idx.key)
                            }, label: {
                                Image(systemName: "trash.fill")
                            })
                            
                            Text("Item \(idx.key) paused - \(bytesUploaded) / \(totalBytes)")
                            
                            Spacer()
                        }
                    case .uploaded(let url):
                        HStack {
                            Text("Item \(idx.key) - Has been uploaded")
                            
                            Spacer()
                        }
                    case .failed(let error):
                        HStack(spacing: 8) {
                            Button(action: {
                                tusWrapper.clearUpload(id: idx.key)
                            }, label: {
                                Image(systemName: "trash.fill")
                            })
                            
                            Text("Item \(idx.key) failed")
                            
                            Spacer()
                        }
                    }
                }
            }.padding([.leading, .trailing])
        }
    }
}
