//
//  ViewController.swift
//  TUSKit
//
//  Created by mmasterson on 04/05/2020.
//  Copyright (c) 2020 mmasterson. All rights reserved.
//

import UIKit
import TUSKit
import PhotosUI

/// This example viewcontroller demonstrates how to upload using a PHPickerViewController, or UIImagePickerController for ios 13 and below.
/// From iOS 14 and up you can select multiple images in 1 go. For iOS 13 and below you can select multiple images one by one.
class ViewController: UIViewController, TUSDelegate, UINavigationControllerDelegate {
    
    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController(nibName: nil, bundle: nil)
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image", "public.movie"]
        return picker
    }()
    
    @available(iOS 14, *)
    lazy var phPicker: PHPickerViewController = {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.selectionLimit = 3
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        return picker
    }()
    
    @IBOutlet weak var numberOfFilesLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var numberOfFilesUploadingLabel: UILabel!
    @IBOutlet weak var numberOfFileUploadLabel: UILabel!
    
    var files: [URL] = []
    var numOfUploaded = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the deleagte of TUSClient
        TUSClient.shared.delegate = self
    }
    
    func updateLabel() {
        if files.count == 1 {
            numberOfFilesLabel.text = "1 file ready for upload"
        } else {
            numberOfFilesLabel.text = "\(files.count) files ready for upload"
        }
        numberOfFilesUploadingLabel.text = "\(String(describing: TUSClient.shared.currentUploads!.count)) files uploading"
        numberOfFileUploadLabel.text = "\(numOfUploaded) files uploaded"
    }
    
    @IBAction func addFileAction(_ sender: Any) {
        if #available(iOS 14, *) {
            present(phPicker, animated: true, completion: nil)
        } else {
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    @IBAction func uploadAction(_ sender: Any) {
        if (TUSClient.shared.status == TUSClientStaus.ready
                && TUSClient.shared.currentUploads!.count > 0
                && files.count <= 0) {
            TUSClient.shared.resumeAll()
            return;
        }
        
        for file in files {
            let number = Int.random(in: 0 ..< 1000) //TODO: Remove before release: this is only set so we can run multiple files while developer
            
            //When you have a file, create an upload, and give it a Id.
            let upload: TUSUpload = TUSUpload(withId:  String(number), andFilePathURL: file, andFileType: ".jpeg")
            upload.metadata = ["hello": "world"]
            //Create or resume upload
            TUSClient.shared.createOrResume(forUpload: upload, withCustomHeaders: ["Header": "Value"])
        }
        updateLabel()
    }
    
    //MARK: TUSClient delegate
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        print("Global upload: \(uploaded)/\(remaining)");
        self.progressLabel.text = "\(uploaded)/\(remaining)"
        self.progressBar.progress = Float(uploaded) / Float(remaining)
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        print("Upload for: \(upload.id) \(uploaded)/\(remaining)");
    }
    
    func TUSSuccess(forUpload upload: TUSUpload) {
        TUSClient.shared.getFile(forUpload: upload)
        numOfUploaded = numOfUploaded + 1
        // Delay the update a second, because we will get the pending uploads
        // from TUS. After a upload has finished it may take some short amount of time after the
        // persistence layer has been updated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateLabel()
        }
    }
    
    func TUSFailure(forUpload upload: TUSUpload?, withResponse response: TUSResponse?, andError error: Error?) {
        if (response != nil) {
            print(response!.message!)
        }
        if (error != nil) {
            print(error!.localizedDescription)
        }
    }
    
    //MARK: - Uploading a file
    
    /// Add file to list to upload, stores its data
    /// - Parameters:
    ///   - data: The image data
    ///   - url: The path to the image
    func addFile(data: Data, to url: URL) {
        files.append(url)
        updateLabel()
        
        let writingURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            try data.write(to: writingURL)
            
        } catch let error {
            print(error)
        }
    }
}

@available(iOS 14, *)
extension ViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        let identifiers = results.compactMap(\.assetIdentifier)
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        print(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            print("Fetching data from \(asset)")
            PHImageManager.default().requestImageData(for: asset, options: nil) { data, _, _, _ in
                guard let data = data else {
                    print("No data found for asset")
                    return
                }
                
                asset.requestContentEditingInput(with: nil) { [weak self] input, info in
                    guard let self = self else { return }
                    if let input = input, let url = input.fullSizeImageURL {
                        self.addFile(data: data, to: url)
                    } else {
                        print("Could not retrieve url for asset")
                    }
                }
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
}

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var targetURL: URL?
        if let url = info[.referenceURL] as? URL {
            targetURL = url
        } else if #available(iOS 11.0, *) {
            targetURL = info[.imageURL] as? URL
        }
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.editedImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 1),
              let url = targetURL  else {
            assertionFailure("Could not get data or url for image")
            return
        }
        
        addFile(data: data, to: url)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
}
