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
            
            dataFrom(pickerResults: results) { [unowned tusClient] urls in
                do {
                    try tusClient.uploadFiles(filePaths: urls)
                } catch {
                    print("Error is \(error)")
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func dataFrom(pickerResults: [PHPickerResult], completed: @escaping ([URL]) -> Void) {
            let identifiers = pickerResults.compactMap(\.assetIdentifier)
            
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assetURLs = [URL]()
            
            var expectedCount = pickerResults.count // Can't rely on count in enumerateObjects in Xcode 13
            fetchResult.enumerateObjects { asset, count, _ in
                asset.getURL { url in
                    expectedCount -= 1
                    guard let url = url else {
                        print("No url found for asset")
                        return
                    }
                    assetURLs.append(url)

                    if expectedCount == 0 {
                        completed(assetURLs)
                    }
                }
                
            }
           
        }
        
        deinit {
            
        }
    }
}

private extension PHAsset {
    // From https://stackoverflow.com/questions/38183613/how-to-get-url-for-a-phasset
    func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
        if self.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            self.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
            })
        } else if self.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: self, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
}
