//
//  PhotoPicker.swift
//  TUSKitExample
//
//  Created by Tjeerd in ‘t Veen on 14/09/2021.
//

import SwiftUI
import UIKit
import PhotosUI
import TUSKit

struct PhotoPicker: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentationMode
    
    let tusClient: TUSClient
    
    init(tusClient: TUSClient) {
        self.tusClient = tusClient
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.selectionLimit = 30
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, tusClient: tusClient)
    }
    
    // Use a Coordinator to act as your PHPickerViewControllerDelegate
    class Coordinator: PHPickerViewControllerDelegate {
      
        private let parent: PhotoPicker
        private let tusClient: TUSClient
        
        init(_ parent: PhotoPicker, tusClient: TUSClient) {
            self.parent = parent
            self.tusClient = tusClient
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            
            dataFrom(pickerResults: results) { [unowned tusClient] data in
                print("Received \(data.count) results")
                try! tusClient.uploadMultiple(dataFiles: data)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func dataFrom(pickerResults: [PHPickerResult], completed: @escaping ([Data]) -> Void) {
            let identifiers = pickerResults.compactMap(\.assetIdentifier)
            
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assetData = [Data]()
            
            fetchResult.enumerateObjects { asset, count, _ in
                
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: nil) { data, _, _, _ in
                    guard let data = data else {
                        print("No data found for asset")
                        return
                    }
                    assetData.append(data)
                    if count == pickerResults.count - 1 {
                        completed(assetData)
                    }

                }
            }
           
        }
        
        deinit {
            
        }
    }
}
