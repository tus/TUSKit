//
//  TUSFileManager.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import UIKit

class TUSFileManager: NSObject {
    // MARK: Private file storage methods
    
    internal func fileStorePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory: String = paths[0]
        return documentsDirectory.appending(TUSConstants.TUSFileDirectoryName)
    }
    
    internal func createFileDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: fileStorePath(), withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription);
        }
    }
    
    internal func fileExists(withName name: String) -> Bool {
        return FileManager.default.fileExists(atPath: fileStorePath().appending(name))
    }
    
    internal func moveFile(atLocation location: URL, withFileName name: String) {
        do {
            try FileManager.default.moveItem(at: location, to: URL(string: fileStorePath().appending(name))!)
        } catch(let error){
            print(error)
        }
    }
    
    internal func writeData(withData data: Data, andFileName name: String) {
        do {
            try data.write(to: URL(string: fileStorePath().appending(name))!)
        } catch (let error) {
            print(error)
        }
    }
}
