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
            Text("TUSKit Demo")
                .font(.title)
                .padding()
            
            Button("Select image") {
                showingImagePicker.toggle()
            }.sheet(isPresented:$showingImagePicker, content: {
                self.photoPicker
                                                     })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @State static var isPresented = false
    static let tusClient = TUSClient(config: TUSConfig(server: URL(string: "https://tusd.tusdemo.net/files")!))
    static var previews: some View {
        let photoPicker = PhotoPicker(tusClient: tusClient)
        ContentView(photoPicker: photoPicker)
    }
}
