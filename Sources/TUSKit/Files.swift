//
//  Files.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 15/09/2021.
//

import Foundation
#if os(iOS)
import MobileCoreServices
#endif

enum FilesError: Error {
    case relatedFileNotFound
}

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
    
    /// Loads all metadata (decoded plist files) from the target directory.
    /// - Important:Metadata assumes to be in the same directory as the file it references.
    /// This means that once retrieved, this method updates the metadata's filePath to the directory that the metadata is in.
    /// This happens, because theoretically the documents directory can change. Meaning that metadata's filepaths are invalid.
    /// By updating the filePaths back to the metadata's filepath, we keep the metadata and its related file in sync.
    /// It's a little magic, but it helps prevent strange issues.
    /// - Throws: File related errors
    /// - Returns: An array of UploadMetadata types
    static func loadAllMetadata() throws -> [UploadMetadata] {
        let directoryContents = try FileManager.default.contentsOfDirectory(at: targetDirectory, includingPropertiesForKeys: nil)
        
        // if you want to filter the directory contents you can do like this:
        let files = directoryContents.filter{ $0.pathExtension == "plist" }
        let decoder = PropertyListDecoder()
        
        return files.compactMap { url in
            
            if let data = try? Data(contentsOf: url) {
                let metaData = try? decoder.decode(UploadMetadata.self, from: data)
                        
                // The documentsDirectory can change between restarts (at least during testing). So we update the filePath to match the existing plist again. To avoid getting an out of sync situation where the filePath still points to a dir in a different directory than the plist.
                // (The plist and image to upload should always be in the same dir together).
                metaData?.filePath = url.deletingPathExtension()
                
                return metaData
            }
            
            // TODO: Handle error when it can't be decoded?
            return nil
        }
    }
    
    /// Copy a file from location to a TUS directory, get the URL from the new location
    /// - Parameter location: The location where to copy a file from
    /// - Parameter id: The unique identifier for the data. Will be used as a filename.
    /// - Throws: Any error related to file handling.
    /// - Returns:The URL of the new location.
    @discardableResult
    static func copy(from location: URL, id: UUID) throws -> URL {
        try makeDirectoryIfNeeded()
        
        // TODO: Prefix with file:// if location can't be found
        
        // We don't use lastPathComponent (filename) because then you can't add the same file file.
        // With a unique name, you can upload the same file twice if you want.
        let fileName = id.uuidString + location.lastPathComponent
        let targetLocation = targetDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.copyItem(atPath: location.path, toPath: targetLocation.path)
        return targetLocation
    }
    
    /// Store data in the TUS directory, get a URL of the location
    /// - Parameter data: The data to store
    /// - Parameter id: The unique identifier for the data. Will be used as a filename.
    /// - Throws: Any file related error (e.g. can't save)
    /// - Returns: The URL of the stored file
    @discardableResult
    static func store(data: Data, id: UUID) throws -> URL {
        try makeDirectoryIfNeeded()
        let fileName = id.uuidString
        
        let targetLocation = targetDirectory.appendingPathComponent(fileName)
        try data.write(to: targetLocation)
        return targetLocation
    }
    
    /// Removes metadata and its related file from disk
    /// - Parameter metaData: The metadata description
    /// - Throws: Any error from FileManager when removing a file.
    static func removeFileAndMetadata(_ metaData: UploadMetadata) throws {
        let filePath = metaData.filePath
        let metaDataPath = metaData.filePath.appendingPathExtension("plist")
        
        try FileManager.default.removeItem(at: filePath)
        try FileManager.default.removeItem(at: metaDataPath)
    }
    
    /// Store the metadata of a file. Will follow a convention, based on a file's url, to determine where to store it.
    /// Hence no need to give it a location to store the metadata.
    /// The reason to use this method is persistence between runs. E.g. Between app launches or background threads.
    /// - Parameter metaData: The metadata of a file to store.
    /// - Throws: Any error related to file handling
    /// - Returns: The URL of the location where the metadata is stored.
    @discardableResult
    static func encodeAndStore(metaData: UploadMetadata) throws -> URL {
        guard FileManager.default.fileExists(atPath: metaData.filePath.path) else {
            // Could not find the file that's related to this metadata.
            throw FilesError.relatedFileNotFound
        }
        
        let targetLocation = metaData.filePath.appendingPathExtension("plist")
        try makeDirectoryIfNeeded()
        
        let encoder = PropertyListEncoder()
        let encodedData = try encoder.encode(metaData)
        try encodedData.write(to: targetLocation)
        return targetLocation
    }
    
    static func makeDirectoryIfNeeded() throws {
        let doesExist = FileManager.default.fileExists(atPath: targetDirectory.path, isDirectory: nil)
        
        if !doesExist {
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }
    }
    
    static func clearTUSDirectory() throws {
        guard FileManager.default.fileExists(atPath: targetDirectory.path, isDirectory: nil) else {
            return
        }
        
        for file in try FileManager.default.contentsOfDirectory(atPath: targetDirectory.path) {
            try FileManager.default.removeItem(atPath: targetDirectory.appendingPathComponent(file).path)
        }
    }
    
}

extension URL {
    var mimeType: String {
        let pathExtension = self.pathExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}
