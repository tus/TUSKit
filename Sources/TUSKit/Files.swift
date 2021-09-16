//
//  Files.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 15/09/2021.
//

import Foundation

/// This type handles files, it stores, and copies.
/// Basically it adds convenience methods to handle file loading.
/// Uses FileManager.default underwater, hence why methods work statically
final class Files {
    
    static private var TUSDirectory = "TUS"
    
    static var targetDirectory: URL {
        // TODO: Consider using cache dir? Or mac only?
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
        
        // TODO: Prefix with file:// if location can't be found
        
        // We don't use lastPathComponent (filename) because then you can't add the same file file.
        // With a unique name, you can upload the same file twice if you want.
        let fileName = UUID().uuidString
        
        let targetLocation = targetDirectory.appendingPathComponent(fileName)
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
