//
//  DocumentPicker.swift
//  TUSKitExample
//
//  Created by Donny Wals on 30/01/2023.
//

import Foundation
import TUSKit
import UIKit
import SwiftUI

struct DocumentPicker: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentationMode
    
    let tusClient: TUSClient
    
    init(tusClient: TUSClient) {
        self.tusClient = tusClient
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .image, .pdf])
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, tusClient: tusClient)
    }
    
    // Use a Coordinator to act as your PHPickerViewControllerDelegate
    class Coordinator: NSObject, UIDocumentPickerDelegate {
      
        private let parent: DocumentPicker
        private let tusClient: TUSClient
        
        init(_ parent: DocumentPicker, tusClient: TUSClient) {
            self.parent = parent
            self.tusClient = tusClient
            
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var files = [Data]()
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    continue
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    files.append(data)
                } catch {
                    print(error)
                }
            }
            
            do {
                try self.tusClient.uploadMultiple(dataFiles: files)
                tusClient.scheduleBackgroundTasks()
            } catch {
                print(error)
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
        
    }
}

