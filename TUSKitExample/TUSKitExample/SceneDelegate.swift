//
//  SceneDelegate.swift
//  TUSKitExample
//
//  Created by Tjeerd in ‘t Veen on 14/09/2021.
//

import UIKit
import SwiftUI
import TUSKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    var tusClient: TUSClient!
    var wrapper: TUSWrapper!

    @State var isPresented = false
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        do {
            tusClient = try TUSClient(server: URL(string: "https://tusd.tusdemo.net/files")!, sessionIdentifier: "TUS DEMO", storageDirectory: URL(string: "/TUS")!, chunkSize: 100 * 1024 * 1024)
            wrapper = TUSWrapper(client: tusClient)
            let remainingUploads = tusClient.start()
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
            let ids = try tusClient.failedUploadIDs()
            for id in ids {
                // You can either retry a failed upload...
                try tusClient.retry(id: id)
                // ...alternatively, you can delete them too
                // tusClient.removeCacheFor(id: id)
            }


            /*
              // You can get previous uploads with tusClient.findPreviousUploads()
              let previousUploads = try tusClient.findPreviousUploads()
              for previousUpload in previousUploads {
                 print("\(previousUpload) Previous upload")
              }
             */
        } catch {
            assertionFailure("Could not fetch failed id's from disk, or could not instantiate TUSClient \(error)")
        }
        
        let contentView = ContentView(tusWrapper: wrapper)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // We can already trigger background tasks. Once the background-scheduler runs, the tasks will upload.
        tusClient.scheduleBackgroundTasks()
    }
}
