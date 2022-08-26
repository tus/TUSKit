//
//  TUSBackground.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 23/09/2021.
//

import Foundation
import BackgroundTasks

#if os(iOS)
/// Perform background uploading
final class TUSBackground {
    
    // Same as in the Info.plist `Permitted background task scheduler identifiers`
    private static let identifier = "io.tus.uploading"
    
    private var currentTask: ScheduledTask?
    private let api: TUSAPI
    private let files: Files
    private let chunkSize: Int
    
    init(api: TUSAPI, files: Files, chunkSize: Int) {
        self.api = api
        self.files = files
        self.chunkSize = chunkSize
        
        registerForBackgroundTasks()
    }
    
    func registerForBackgroundTasks() {
#if targetEnvironment(simulator)
        return
#else
        BGTaskScheduler.shared.register(forTaskWithIdentifier: type(of: self).identifier, using: nil) { [weak self] bgTask in
            guard let self = self else { return }
            guard let backgroundTask = bgTask as? BGProcessingTask else {
                return
            }
            
            guard let tusTask = self.firstTask() else {
                backgroundTask.setTaskCompleted(success: true)
                return
            }
            
            self.currentTask = tusTask
                    
            backgroundTask.expirationHandler = {
                // Clean up so app won't get terminated and negatively impact iOS'background rating.
                tusTask.cancel()
            }
            
            tusTask.run { result in
                switch result {
                case .success:
                    backgroundTask.setTaskCompleted(success: true)
                case .failure:
                    backgroundTask.setTaskCompleted(success: false)
                }
            }
            
            self.scheduleSingleTask() // Try and schedule another task.
        }
#endif
    }
    
    func scheduleBackgroundTasks() {
        #if targetEnvironment(simulator)
        print("Background tasks aren't supported on simulator (iOS limitation). Ignoring.")
        #else
        scheduleSingleTask()
        #endif
    }
    
    /// Try and schedule another task. But, might not schedule a task if none are available.
    private func scheduleSingleTask() {
        guard firstTask() != nil else {
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: type(of: self).identifier)
        request.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task \(error)")
        }
        
    }
    
    /// Return first available task
    /// - Returns: A possible task to run
    private func firstTask() -> ScheduledTask? {
        guard let allMetaData = try? files.loadAllMetadata() else {
            return nil
        }
        
        return allMetaData.firstMap { metaData in
            try? taskFor(metaData: metaData, api: api, files: files, chunkSize: chunkSize)
        }
    }
    
}

private extension Array {
    /// `firstMap` is like `first(where:)`, but instead of returning the first element of the array, it returns the first transformed (mapped) element .
    /// You have to pass a `transform` closure. Whatever non-nil you return, will be returned from the method.
    /// - Parameter transform: An element to transform to. If it returns a new value, that value will be returned from this method.
    /// - Returns:An option new value.
    func firstMap<TransformedElement>(where transform: (Element) throws -> TransformedElement?) rethrows -> TransformedElement? {
        for element in self {
            if let otherElement = try transform(element) {
                return otherElement
            }
        }
        return nil
    }
}
#endif
