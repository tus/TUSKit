//
//  ViewController.swift
//  TUSKit
//
//  Created by mmasterson on 04/05/2020.
//  Copyright (c) 2020 mmasterson. All rights reserved.
//

import UIKit
import TUSKit

class ViewController: UIViewController, TUSDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        TUSClient.shared.delegate = self
        let upload: TUSUpload = TUSUpload(withId: "image-1", andFilePathURL: URL(string: "")!)
        
        TUSClient.shared.createOrResume(forUpload: upload)
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

