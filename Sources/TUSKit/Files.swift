//
//  Files.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 15/09/2021.
//

import Foundation

enum FilesError: Error {
    case relatedFileNotFound
    case dataIsEmpty
    case unknownError
}

/// This type handles the storage for `TUSClient`
/// It makes sure that files (that are to be uploaded) are properly stored, together with their metaData.
/// Underwater it uses `FileManager.default`.
final class Files {
    
    let storageDirectory: URL
    
    private let queue = DispatchQueue(label: "com.tuskit.files")
    
    /// Pass a directory to store the local cache in.
    /// - Parameter storageDirectory: Leave nil for the documents dir. Pass a relative path for a dir inside the documents dir. Pass an absolute path for storing files there.
    /// - Throws: File related errors when it can't make a directory at the designated path.
    init(storageDirectory: URL?) throws {
        func removeLeadingSlash(url: URL) -> String {
            if url.absoluteString.first == "/" {
                return String(url.absoluteString.dropFirst())
            } else {
                return url.absoluteString
            }
        }
        
        func removeTrailingSlash(url: URL) -> String {
            if url.absoluteString.last == "/" {
                return String(url.absoluteString.dropLast())
            } else {
                return url.absoluteString
            }
        }
        
        guard let storageDirectory = storageDirectory else {
            self.storageDirectory = type(of: self).documentsDirectory.appendingPathComponent("TUS")
            return
        }
        
        // If a path is relative, e.g. blabla/mypath or /blabla/mypath. Then it's a folder for the documentsdir
        let isRelativePath = removeTrailingSlash(url: storageDirectory) == storageDirectory.relativePath || storageDirectory.absoluteString.first == "/"
        
        let dir = removeLeadingSlash(url: storageDirectory)

        if isRelativePath {
            self.storageDirectory = type(of: self).documentsDirectory.appendingPathComponent(dir)
        } else {
            if let url = URL(string: dir) {
                self.storageDirectory = url
            } else {
                assertionFailure("Can't recreate URL")
                self.storageDirectory = type(of: self).documentsDirectory.appendingPathComponent("TUS")
            }
        }
        
        try makeDirectoryIfNeeded()
    }
    
    static private var documentsDirectory: URL {
#if os(macOS)
        var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if let bundleId = Bundle.main.bundleIdentifier {
            directory = directory.appendingPathComponent(bundleId)
        }
        return directory
#else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
#endif
        
    }
    
    /// Loads all metadata (decoded plist files) from the target directory.
    /// - Important:Metadata assumes to be in the same directory as the file it references.
    /// This means that once retrieved, this method updates the metadata's filePath to the directory that the metadata is in.
    /// This happens, because theoretically the documents directory can change. Meaning that metadata's filepaths are invalid.
    /// By updating the filePaths back to the metadata's filepath, we keep the metadata and its related file in sync.
    /// It's a little magic, but it helps prevent strange issues.
    /// - Throws: File related errors
    /// - Returns: An array of UploadMetadata types
    func loadAllMetadata() throws -> [UploadMetadata] {
        try queue.sync {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            
            // if you want to filter the directory contents you can do like this:
            let files = directoryContents.filter{ $0.pathExtension == "plist" }
            let decoder = PropertyListDecoder()
            
            let metaData: [UploadMetadata] = files.compactMap { url in
                if let data = try? Data(contentsOf: url) {
                    let metaData = try? decoder.decode(UploadMetadata.self, from: data)
                    
                    // The documentsDirectory can change between restarts (at least during testing). So we update the filePath to match the existing plist again. To avoid getting an out of sync situation where the filePath still points to a dir in a different directory than the plist.
                    // (The plist and file to upload should always be in the same dir together).
                    metaData?.filePath = url.deletingPathExtension()
                    
                    return metaData
                }
                
                // Improvement: Handle error when it can't be decoded?
                return nil
            }
            
            return metaData
        }
    }
    
    /// Copy a file from location to a TUS directory, get the URL from the new location
    /// - Parameter location: The location where to copy a file from
    /// - Parameter id: The unique identifier for the data. Will be used as a filename.
    /// - Throws: Any error related to file handling.
    /// - Returns:The URL of the new location.
    @discardableResult
    func copy(from location: URL, id: UUID) throws -> URL {
        try makeDirectoryIfNeeded()
        
        // We don't use lastPathComponent (filename) because then you can't add the same file file.
        // With a unique name, you can upload the same file twice if you want.
        let fileName = id.uuidString + location.lastPathComponent
        let targetLocation = storageDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.copyItem(atPath: location.path, toPath: targetLocation.path)
        return targetLocation
    }
    
    /// Store data in the TUS directory, get a URL of the location
    /// - Parameter data: The data to store
    /// - Parameter id: The unique identifier for the data. Will be used as a filename.
    /// - Throws: Any file related error (e.g. can't save)
    /// - Returns: The URL of the stored file
    @discardableResult
    func store(data: Data, id: UUID, preferredFileExtension: String? = nil) throws -> URL {
        try queue.sync {
            guard !data.isEmpty else { throw FilesError.dataIsEmpty }
            try makeDirectoryIfNeeded()
            
            let fileName: String
            if let fileExtension = preferredFileExtension {
                fileName = id.uuidString + fileExtension
            } else {
                fileName = id.uuidString
            }
            
            let targetLocation = storageDirectory.appendingPathComponent(fileName)
            try data.write(to: targetLocation, options: .atomic)
            return targetLocation
        }
    }
    
    /// Removes metadata and its related file from disk
    /// - Parameter metaData: The metadata description
    /// - Throws: Any error from FileManager when removing a file.
    func removeFileAndMetadata(_ metaData: UploadMetadata) throws {
        let filePath = metaData.filePath
        let fileName = filePath.lastPathComponent
        let metaDataPath = storageDirectory.appendingPathComponent(fileName).appendingPathExtension("plist")
        
        try queue.sync {
            try FileManager.default.removeItem(at: metaDataPath)
#if os(iOS)
            try FileManager.default.removeItem(at: filePath)
#endif
        }
    }
    
    /// Store the metadata of a file. Will follow a convention, based on a file's url, to determine where to store it.
    /// Hence no need to give it a location to store the metadata.
    /// The reason to use this method is persistence between runs. E.g. Between app launches or background threads.
    /// - Parameter metaData: The metadata of a file to store.
    /// - Throws: Any error related to file handling
    /// - Returns: The URL of the location where the metadata is stored.
    @discardableResult
    func encodeAndStore(metaData: UploadMetadata) throws -> URL {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: metaData.filePath.path) else {
                // Could not find the file that's related to this metadata.
                throw FilesError.relatedFileNotFound
            }
            let fileName = metaData.filePath.lastPathComponent
            let targetLocation = storageDirectory.appendingPathComponent(fileName).appendingPathExtension("plist")
            try self.makeDirectoryIfNeeded()
            
            let encoder = PropertyListEncoder()
            let encodedData = try encoder.encode(metaData)
            try encodedData.write(to: targetLocation, options: .atomic)
            return targetLocation
        }
    }
    
    /// Load metadata from store and find matching one by id
    /// - Parameter id: Id to find metadata
    /// - Returns: optional `UploadMetadata` type
    func findMetadata(id: UUID) throws -> UploadMetadata? {
        return try loadAllMetadata().first(where: { metaData in
            metaData.id == id
        })
    }
    
    func makeDirectoryIfNeeded() throws {
        let doesExist = FileManager.default.fileExists(atPath: storageDirectory.path, isDirectory: nil)
        
        if !doesExist {
            try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }
    
    func clearCacheInStorageDirectory() throws {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: storageDirectory.path, isDirectory: nil) else {
                return
            }
            
            try FileManager.default.removeItem(at: storageDirectory)
        }
    }
    
}

