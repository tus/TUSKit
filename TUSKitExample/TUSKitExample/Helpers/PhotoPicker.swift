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

/// In this example you can see how you can pass on imagefiles to the TUSClient.
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
            var images = [Data]()
            results.forEach { result in
                let semaphore = DispatchSemaphore(value: 0)
                result.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] (object, error) in
                    defer {
                        semaphore.signal()
                    }
                    guard let self = self else { return }
                    if let image = object as? UIImage {
                        
                        if let imageData = image.jpegData(compressionQuality: 0.7) {
                            images.append(imageData)
                        } else {
                            print("Could not retrieve image data")
                        }
                        
                        if results.count == images.count {
                            print("Received \(images.count) images")
                            do {
                                try self.tusClient.uploadMultiple(dataFiles: images)
                            } catch {
                                print("Error is \(error)")
                            }
                        }
                        
                    } else {
                        if let object {
                            print(object)
                        }
                        if let error {
                            print(error)
                        }
                    }
                })
                semaphore.wait()
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
    }
}

