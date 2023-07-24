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
    
    /// Can be helpful to set default tab while developing
    @State private var activeTab = 0
    
    var body: some View {
        TabView(selection: $activeTab) {
            FilePickerView(
                photoPicker: PhotoPicker(tusClient: tusWrapper.client),
                filePicker: DocumentPicker(tusClient: tusWrapper.client)
            )
            .tabItem {
                VStack {
                    Image(systemName: Icon.uploadFile.rawValue)
                    Text("Upload files")
                }
            }.tag(0)
            
            NavigationView {
                UploadsListView()
                    .environmentObject(tusWrapper)
                    .navigationTitle("Uploads")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                VStack {
                    Image(systemName: Icon.uploadList.rawValue)
                    Text("Uploads")
                }
            }.tag(1)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var tusWrapper: TUSWrapper = {
        let client = try! TUSClient(
            server:               URL(string: "https://tusd.tusdemo.net/files")!,
            sessionIdentifier:    "TUSClient",
            sessionConfiguration: .default,
            storageDirectory:     URL(string: "TUS")!,
            chunkSize:            0
        )
        let wrapper = TUSWrapper(client: client)
        /// Set this to begin with mock data in uploads list screen in Preview
//        wrapper.setMockUploadRecords()
        return wrapper
    }()
    
    static var previews: some View {
        ContentView(tusWrapper: tusWrapper)
    }
}
