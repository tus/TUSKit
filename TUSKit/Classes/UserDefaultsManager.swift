//
//  UserDefaultsManager.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import Foundation

class UserDefaultsManager {

    static let shared = UserDefaultsManager()

    var environment: TUSUploadStatus? {
       get {
        guard let status = UserDefaults.standard.value(forKey: TUSConstants.kSavedTUSUploadStatusDefaultsKey) as? String else {
               return nil
           }
           return TUSUploadStatus(rawValue: status)
       }
       set(status) {
           UserDefaults.standard.set(status?.rawValue, forKey: TUSConstants.kSavedTUSUploadStatusDefaultsKey)
       }
    }
}
