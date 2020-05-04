//
//  ViewController.swift
//  TUSKit
//
//  Created by mmasterson on 04/05/2020.
//  Copyright (c) 2020 mmasterson. All rights reserved.
//

import UIKit
import TUSKit

class ViewController: UIViewController, TUSDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let imagePicker = UIImagePickerController()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Image picker setup for example.
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
        
        //Set the deleagte of TUSClient
        TUSClient.shared.delegate = self
    }
    
   
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if #available(iOS 11.0, *) {
            guard let imageURL = info[.imageURL] else {
                return
            }
            let number = Int.random(in: 0 ..< 100) //TODO: Remove before release: this is only set so we can run multiple files while developer
            
            //When you have a file, create an upload, and give it a Id.
            let upload: TUSUpload = TUSUpload(withId: String(format: "%@%@", "image", String(number)), andFilePathURL: imageURL as! URL, andFileType: ".jpeg")
            //Create or resume upload
            TUSClient.shared.createOrResume(forUpload: upload)

        }
        
        dismiss(animated: true) {
            self.present(self.imagePicker, animated: true, completion: nil) //Force reopen on close for testing purposes
        }
    }
//
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: TUSClient Deleagte
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
    }
    
    func TUSSuccess(forUpload upload: TUSUpload, withResponse response: TUSResponse) {
        //
    }
    
    func TUSFailure(forUpload upload: TUSUpload, withResponse response: TUSResponse, andError error: Error) {
        //
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

