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
        
        
        wrapper = TUSWrapper(client: AppDelegate.tusClient)
        let contentView = ContentView(tusWrapper: wrapper)
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // We can already trigger background tasks. Once the background-scheduler runs, the tasks will upload.
        //tusClient.scheduleBackgroundTasks()
    }
}
