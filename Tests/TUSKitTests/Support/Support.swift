//
//  File.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 01/10/2021.
//

import Foundation
import TUSKit // No testable import to properly use TUSClient

func makeDirectoryIfNeeded(url: URL) throws {
    let doesExist = FileManager.default.fileExists(atPath: url.path, isDirectory: nil)
    
    if !doesExist {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

func clearDirectory(dir: URL) {
    do {
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        for name in names
        {
            let path = "\(dir.path)/\(name)"
            try FileManager.default.removeItem(atPath: path)
        }
    } catch {
        print(error.localizedDescription)
    }
}

func makeClient(storagePath: URL?) -> TUSClient {
    let liveDemoPath = URL(string: "https://tusd.tusdemo.net/files")!
    
    // We don't use a live URLSession, we mock it out.
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    let client = TUSClient(config: TUSConfig(server: liveDemoPath), sessionIdentifier: "TEST", storageDirectory: storagePath, session: URLSession.init(configuration: configuration))
    return client
}

/// Base 64 extensions
extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

}

extension Dictionary {
    
    /// Case insenstiive subscripting. Only for string keys.
    /// We downcast to string to support AnyHashable keys.
    public subscript(caseInsensitive key: Key) -> Value? {
        guard let someKey = key as? String else {
            return nil
        }
        
        let lcKey = someKey.lowercased()
        for k in keys {
            if let aKey = k as? String {
                if lcKey == aKey.lowercased() {
                    return self[k]
                }
            }
        }
        return nil
    }
}
