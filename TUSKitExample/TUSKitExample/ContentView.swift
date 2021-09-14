//
//  ContentView.swift
//  TUSKitExample
//
//  Created by Tjeerd in ‘t Veen on 14/09/2021.
//

import SwiftUI
import TUSKit
import PhotosUI

struct ContentView: View {
    
    let photoPicker: PhotoPicker
    
    @State private var showingImagePicker = false
    
    init(photoPicker: PhotoPicker) {
        self.photoPicker = photoPicker
    }

    var body: some View {
        
        
        VStack {
            Text("Hello, world!")
                .padding()
            
            Button("Select image") {
                showingImagePicker.toggle()
            }.sheet(isPresented:$showingImagePicker, content: {
//                photoPicker.
                PhotoPicker()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @State static var isPresented = false
    
    static var previews: some View {
        let photoPicker = PhotoPicker()
        ContentView(photoPicker: photoPicker)
    }
}

/*
struct ContentView: View {
    @State private var isPresented: Bool = false
    var body: some View {
        Button("Present Picker") {
            isPresented.toggle()
        }.sheet(isPresented: $isPresented) {
            let configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
            PhotoPicker(configuration: configuration, isPresented: $isPresented)
        }
    }
}

*/
