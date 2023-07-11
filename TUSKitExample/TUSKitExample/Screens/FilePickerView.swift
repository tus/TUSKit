//
//  FilePickerView.swift
//  TUSKitExample
//
//  Created by Donny Wals on 27/02/2023.
//

import Foundation
import SwiftUI
import TUSKit

struct FilePickerView: View {
    let photoPicker: PhotoPicker
    let filePicker: DocumentPicker
    
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    
    init(photoPicker: PhotoPicker, filePicker: DocumentPicker) {
        self.photoPicker = photoPicker
        self.filePicker = filePicker
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("TUSKit Demo")
                .font(.title)
                .padding()
            
            Button("Select image") {
                showingImagePicker.toggle()
            }.sheet(isPresented: $showingImagePicker, content: {
                self.photoPicker
            })
            
            Button("Select file") {
                showingFilePicker.toggle()
            }.sheet(isPresented: $showingFilePicker, content: {
                self.filePicker
            })
        }
    }
}
