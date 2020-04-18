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
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
        
        TUSClient.shared.delegate = self
    }
    
   
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if #available(iOS 11.0, *) {
            guard let imageURL = info[.imageURL] else {
                return
            }
            let number = Int.random(in: 0 ..< 100) //TODO: Remove before release: this is only set so we can run multiple files while developer
            let upload: TUSUpload = TUSUpload(withId: String(format: "%@%@", "image", String(number)), andFilePathURL: imageURL as! URL)
            TUSClient.shared.createOrResume(forUpload: upload)

        } else {
            // Fallback on earlier versions
        }
        dismiss(animated: true) {
            self.present(self.imagePicker, animated: true, completion: nil) //Force reopen on close for testing purposes
        }
    }
//
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
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

