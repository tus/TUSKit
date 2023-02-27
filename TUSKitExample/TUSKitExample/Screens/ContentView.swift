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
    let tusWrapper: TUSWrapper

    var body: some View {
        TabView {
            FilePickerView(
                photoPicker: PhotoPicker(tusClient: tusWrapper.client),
                filePicker: DocumentPicker(tusClient: tusWrapper.client)
            )
            .tabItem {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Upload files")
                }
            }
            
            UploadsView(
                tusWrapper: tusWrapper
            )
            .tabItem {
                VStack {
                    Image(systemName: "list.bullet")
                    Text("Uploads")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @State static var isPresented = false
    static let tusClient = try! TUSClient(server: URL(string: "https://tusd.tusdemo.net/files")!, sessionIdentifier: "TUSClient", storageDirectory: URL(string: "TUS")!)
    static var previews: some View {
        ContentView(tusWrapper: TUSWrapper(client: tusClient))
    }
}
