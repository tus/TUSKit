//
//  TLPhotoViewController.swift
//  TUSKit_Example
//
//  Created by Mark Robert Masterson on 5/24/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Photos
import TLPhotoPicker
import TUSKit

class TLPhotoViewController: UIViewController,TLPhotosPickerViewControllerDelegate, TUSDelegate {
    var selectedAssets = [TLPHAsset]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let viewController = TLPhotosPickerViewController()
        viewController.delegate = self
        var configure = TLPhotosPickerConfigure()
        
        TUSClient.shared.delegate = self
        //configure.nibSet = (nibName: "CustomCell_Instagram", bundle: Bundle.main) // If you want use your custom cell..
        self.present(viewController, animated: true, completion: nil)
    }
    
    //TLPhotosPickerViewControllerDelegate
    func shouldDismissPhotoPicker(withTLPHAssets: [TLPHAsset]) -> Bool {
        // use selected order, fullresolution image
        self.selectedAssets = withTLPHAssets
        
        var file = selectedAssets[0].tempCopyMediaFile { (url, string) in
            //
            var upload = TUSUpload(withId: "File", andFilePathURL: url, andFileType: ".jpeg")
            
            TUSClient.shared.createOrResume(forUpload: upload)
        }
    return true
    }
    func dismissPhotoPicker(withPHAssets: [PHAsset]) {
        // if you want to used phasset.
    }
    func photoPickerDidCancel() {
        // cancel
    }
    func dismissComplete() {
        // picker viewcontroller dismiss completion
    }
    func canSelectAsset(phAsset: PHAsset) -> Bool {
        //Custom Rules & Display
        //You can decide in which case the selection of the cell could be forbidden.
        return true
    }
    func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController) {
        // exceed max selection
    }
    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        // handle denied albums permissions case
    }
    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        // handle denied camera permissions case
    }
    
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
        print(uploaded)
               print(remaining)
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
        print(uploaded)
        print(remaining)
    }
    
    func TUSSuccess(forUpload upload: TUSUpload) {
        print(upload.uploadLocationURL)
        //
    }
    
    func TUSFailure(forUpload upload: TUSUpload?, withResponse response: TUSResponse?, andError error: Error?) {
        //
        if (response != nil) {
            print(response!.message!)
        }
        if (error != nil) {
            print(error!.localizedDescription)
        }
    }
}
