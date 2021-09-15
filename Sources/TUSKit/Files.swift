//
//  Files.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 15/09/2021.
//

import Foundation

final class Files {
    
    static private var TUSDirectory = "TUS"
    
    static var targetDirectory: URL {
        return documentsDirectory.appendingPathComponent(TUSDirectory)
    }
    
    static private var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Copy a file from location to a TUS directory, get the URL from the new location
    /// - Parameter location: The location where to copy a file from
    /// - Throws: Any error related to file handling.
    /// - Returns:The URL of the new location.
    @discardableResult
    static func copy(from location: URL) throws -> URL {
        try makeDirectoryIfNeeded()
        
        let targetLocation = targetDirectory.appendingPathComponent(location.lastPathComponent)
        try FileManager.default.copyItem(atPath: location.path, toPath: targetLocation.path)
        return targetLocation
    }
    
    /// Store data in the TUS directory, get a URL of the location
    /// - Parameter data: The data to store
    /// - Throws: Any file related error (e.g. can't save)
    /// - Returns: The URL of the stored file
    @discardableResult
    static func store(data: Data) throws -> URL {
        try makeDirectoryIfNeeded()
        let fileName = UUID().uuidString
        
        let targetLocation = targetDirectory.appendingPathComponent(fileName)
        try data.write(to: targetLocation)
        return targetLocation
    }
    
    static func makeDirectoryIfNeeded() throws {
        let doesExist = FileManager.default.fileExists(atPath: targetDirectory.path, isDirectory: nil)
        
        if !doesExist {
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }
    }
    
    static func clearTUSDirectory() throws {
        for file in try FileManager.default.contentsOfDirectory(atPath: targetDirectory.path) {
            try FileManager.default.removeItem(atPath: targetDirectory.appendingPathComponent(file).path)
        }
    }
}
