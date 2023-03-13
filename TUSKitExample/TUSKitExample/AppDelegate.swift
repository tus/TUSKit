//
//  AppDelegate.swift
//  TUSKitExample
//
//  Created by Tjeerd in ‘t Veen on 14/09/2021.
//

import UIKit
import TUSKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var tusClient: TUSClient!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            Self.tusClient = try TUSClient(
                server: URL(string: "https://tusd.tusdemo.net/files")!,
                sessionIdentifier: "TUS DEMO",
                sessionConfiguration: .background(withIdentifier: "com.TUSKit.sample"),
                storageDirectory: URL(string: "/TUS")!,
                chunkSize: 0
            )
            
            
            let remainingUploads = Self.tusClient.start()
            switch remainingUploads.count {
            case 0:
                print("No files to upload")
            case 1:
                print("Continuing uploading single file")
            case let nr:
                print("Continuing uploading \(nr) file(s)")
            }
            
            // When starting, you can retrieve the locally stored uploads that are marked as failure, and handle those.
            // E.g. Maybe some uploads failed from a last session, or failed from a background upload.
            let ids = try Self.tusClient.failedUploadIDs()
            for id in ids {
                // You can either retry a failed upload...
                if try Self.tusClient.retry(id: id) == false {
                    try Self.tusClient.removeCacheFor(id: id)
                }
                // ...alternatively, you can delete them too
                // tusClient.removeCacheFor(id: id)
            }
            
            // You can get stored uploads with tusClient.getStoredUploads()
            let storedUploads = try Self.tusClient.getStoredUploads()
            for storedUpload in storedUploads {
                print("\(storedUpload) Stored upload")
                print("\(storedUpload.uploadedRange?.upperBound ?? 0)/\(storedUpload.size) uploaded")
            }
            
            // Make sure you clean up finished uploads after extracting any post-launch information you need
            Self.tusClient.cleanup()
        } catch {
            assertionFailure("Could not fetch failed id's from disk, or could not instantiate TUSClient \(error)")
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622941-application
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Self.tusClient.registerBackgroundHandler(completionHandler, forSession: identifier)
    }
    
}

