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

    @IBOutlet weak var numberOfFilesLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var numberOfFilesUploadingLabel: UILabel!
    @IBOutlet weak var numberOfFileUploadLabel: UILabel!
    
    var files: [URL] = []
    var numOfUploaded = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Image picker setup for example.
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        
        //Set the deleagte of TUSClient
        TUSClient.shared.delegate = self
        
        
//        if let path = Bundle.main.path(forResource: "test", ofType:"mp4") {
//           let number = Int.random(in: 0 ..< 100) //TODO: Remove before release: this is only set so we can run multiple files while developer
//            let upload: TUSUpload = TUSUpload(withId: String(format: "%@%@", "video", String(number)), andFilePathURL: URL(fileURLWithPath: path), andFileType: ".mp4")
//                //Create or resume upload
//
//                TUSClient.shared.createOrResume(forUpload: upload)
//        }
        
    }
    
    func updateLabel() {
        numberOfFilesLabel.text = "\(files.count) of files ready for upload"
        numberOfFilesUploadingLabel.text = "\(String(describing: TUSClient.shared.currentUploads!.count)) files uploading"
        numberOfFileUploadLabel.text = "\(numOfUploaded) files uploaded"
    }
    
    @IBAction func addFileAction(_ sender: Any) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func uploadAction(_ sender: Any) {
        if (files.count <= 0 && TUSClient.shared.currentUploads!.count > 0) {
            TUSClient.shared.resumeAll()
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
    
   
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if #available(iOS 11.0, *) {
            guard let imageURL = info[.imageURL] else {
                return
            }
            
            files.append(imageURL as! URL)
            updateLabel()
        }
        
        dismiss(animated: true) {
        }
    }
//
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: TUSClient Deleagte
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        print("Global upload: \(uploaded)/\(remaining)");
        self.progressLabel.text = "\(uploaded)/\(remaining)"
        self.progressBar.progress = Float(uploaded) / Float(remaining)
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        print("Upload for: \(upload.id) \(uploaded)/\(remaining)");
    }
    
    func TUSSuccess(forUpload upload: TUSUpload) {
        print(upload.uploadLocationURL)
        TUSClient.shared.getFile(forUpload: upload)
        numOfUploaded = numOfUploaded + 1
        // Delay the update a second, because we will get the pending uploads
        // from TUS. After a upload has finished it may take some short amount of time after the
        // persistence layer has been updated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateLabel()
        }
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

