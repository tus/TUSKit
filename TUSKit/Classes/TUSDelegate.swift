//
//  TUSDelegate.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

public protocol TUSDelegate {
    
    func TUSProgress(bytesUploaded uploaded: Int, bytesRemaining remaining: Int)

    func TUSProgress(forUpload upload: TUSUpload, bytesUploaded uploaded: Int, bytesRemaining remaining: Int)

    func TUSSuccess(forUpload upload: TUSUpload)

    func TUSFailure(forUpload upload: TUSUpload, withResponse response: TUSResponse, andError error: Error)

}
