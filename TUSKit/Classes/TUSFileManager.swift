//
//  TUSFileManager.swift
//  TUSKit
//
//  Created by Mark Robert Masterson on 4/16/20.
//

import Foundation

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
            if (error.code != 516) { //516 is failed creating due to already existing
                let response: TUSResponse = TUSResponse(message: "Failed creating TUS directory in documents")
                TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)

            }
        }
    }
    
    internal func fileExists(withName name: String) -> Bool {
        return FileManager.default.fileExists(atPath: fileStorePath().appending(name))
    }

    internal func copyFile(atLocation location: URL, withFileName name: String) -> Bool {
        do {
            try FileManager.default.copyItem(atPath: location.path, toPath: fileStorePath().appending(name))
            return true
        } catch let error as NSError {
            let response: TUSResponse = TUSResponse(message: "Failed moving file \(location.absoluteString) to \(fileStorePath().appending(name)) for TUS folder storage")
            TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
            return false
        }
    }
    
    internal func writeData(withData data: Data, andFileName name: String) -> Bool {
        do {
            try data.write(to: URL(fileURLWithPath: fileStorePath().appending(name)))
            return true
        } catch let error as NSError {
            let response: TUSResponse = TUSResponse(message: "Failed writing data to file \(fileStorePath().appending(name))")
            TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
            return false
        }
    }
    
    internal func deleteFile(withName name: String) -> Bool {
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: fileStorePath().appending(name)))
                return true
        } catch let error as NSError {
            let response: TUSResponse = TUSResponse(message: "Failed deleting file \(name) from TUS folder storage")
            TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
            return false
        }
    }
    
    internal func sizeForLocalFilePath(filePath:String) -> UInt64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = fileAttributes[FileAttributeKey.size]  {
                return (fileSize as! NSNumber).uint64Value
            } else {
                let response: TUSResponse = TUSResponse(message: "Failed to get a size attribute from path: \(filePath)")
                TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: nil)
            }
        } catch {
            let response: TUSResponse = TUSResponse(message: "Failed to get a size attribute from path: \(filePath)")
            TUSClient.shared.delegate?.TUSFailure(forUpload: nil, withResponse: response, andError: error)
        }
        return 0
    }
}
