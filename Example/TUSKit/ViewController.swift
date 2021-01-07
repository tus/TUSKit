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
        for file in files {
            let number = Int.random(in: 0 ..< 1000) //TODO: Remove before release: this is only set so we can run multiple files while developer
            
            //When you have a file, create an upload, and give it a Id.
            var fileData = try! Data(contentsOf: file)
            let upload: TUSUpload = TUSUpload(withId:  String(number), andData: fileData, andFileExtension: ".jpeg")
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
        //
        print(uploaded)
               print(remaining)
        self.progressLabel.text = "\(uploaded)/\(remaining)"
        self.progressBar.progress = Float(uploaded) / Float(remaining)
    }
    
    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int) {
        //
        print(uploaded)
        print(remaining)
    }
    
    func TUSSuccess(forUpload upload: TUSUpload) {
        print(upload.uploadLocationURL)
        TUSClient.shared.getFile(forUpload: upload)
        numOfUploaded = numOfUploaded + 1
        updateLabel()
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

