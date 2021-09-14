//
//  Uploader.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 13/09/2021.
//

import Foundation


// Original Executor tasks:
// Uploading
// Background uploading
// Preparation
// Making requests

/// The Uploader's responsibility is to perform work related to uploading.
/// This includes: Making requests, handling requests, handling errors.
final class Uploader {
    
    func upload(data: Data, offset: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }
}
