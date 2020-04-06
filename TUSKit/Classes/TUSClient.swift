//
//  TUSClient.swift
//  Pods
//
//  Created by Mark Robert Masterson on 4/5/20.
//

import UIKit

class TUSClient: NSObject {
    
    // MARK: Properties
    
    var session: URLSession = TUSSession.shared.session
    var uploadURL: URL?
    var delegate: TUSDelegate?
    
    var currentUploads: [TUSUpload]? {
        get {
            guard let data = UserDefaults.standard.object(forKey: TUSConstants.kSavedTUSUploadsDefaultsKey) as? Data else {
                return nil
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [TUSUpload]
        }
        set(currentUploads) {
            let data = NSKeyedArchiver.archivedData(withRootObject: currentUploads!)
            UserDefaults.standard.set(data, forKey: TUSConstants.kSavedTUSUploadsDefaultsKey)
        }
    }
    
    var status: TUSUploadStatus? {
        get {
            guard let status = UserDefaults.standard.value(forKey: TUSConstants.kSavedTUSClientStatusDefaultsKey) as? String else {
                return nil
            }
            return TUSUploadStatus(rawValue: status)
        }
        set(status) {
            UserDefaults.standard.set(status?.rawValue, forKey: String(format: "%@%@", TUSConstants.kSavedTUSClientStatusDefaultsKey))
        }
    }
    
    //MARK: Initializers
    
    init(withUploadURLString uploadURLString: String) {
        super.init()
        self.uploadURL = URL(string: uploadURLString)
    }
    
    init(withUploadURL uploadURL: URL) {
        super.init()
        self.uploadURL = uploadURL
    }
    
    // MARK: Private file storage methods
    
    private func fileStorePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory: String = paths[0]
        return documentsDirectory.appending(TUSConstants.TUSFileDirectoryName)
    }
    
    private func createFileDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: fileStorePath(), withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription);
        }
    }
    
    private func fileExists(withName name: String) -> Bool {
        return FileManager.default.fileExists(atPath: fileStorePath().appending(name))
    }
    
    private func moveFile(atLocation location: URL, withFileName name: String) {
        do {
            try FileManager.default.moveItem(at: location, to: URL(string: fileStorePath().appending(name))!)
        } catch(let error){
            print(error)
        }
    }
    
    private func writeData(withData data: Data, andFileName name: String) {
        do {
            try data.write(to: URL(string: fileStorePath().appending(name))!)
        } catch (let error) {
            print(error)
        }
    }
    
    // MARK: Create methods
    
    func createOrResume(forUpload upload: TUSUpload) {
        //
        createOrResume(forUpload: upload, withRetries: 0)
    }
    
    func createOrResume(forUpload upload: TUSUpload, withRetries retries: Int) {
        let fileName = String(format: "%@%@", upload.id!, upload.fileType!)
        if (self.fileExists(withName: fileName) == false) {
            if (upload.filePath != nil) {
                self.moveFile(atLocation: upload.filePath!, withFileName: fileName)
            } else if(upload.data != nil) {
                self.writeData(withData: upload.data!, andFileName: fileName)
            }
        }
        
        switch upload.status {
        case .paused:
            //Resume
            break
        case nil:
            //create
            break
        default:
            print()
        }
        
        
    }
    
    // MARK: Mass methods
    
    func resumeAll() {
        for upload in currentUploads! {
            resume(forUpload: upload)
        }
    }
    
    func retryAll() {
        for upload in currentUploads! {
            retry(forUpload: upload)
        }
    }
    
    func cancelAll() {
        for upload in currentUploads! {
            cancel(forUpload: upload)
        }
    }
    
    func cleanUp() {
        for upload in currentUploads! {
            cleanUp(forUpload: upload)
        }
    }
    
    
    // MARK: Methods for one upload
    
    func resume(forUpload upload: TUSUpload) {
        
    }
    
    func retry(forUpload upload: TUSUpload) {
        
    }
    
    func cancel(forUpload upload: TUSUpload) {
        
    }
    
    func cleanUp(forUpload upload: TUSUpload) {
        
    }
    
    // MARK: Private Networking / Upload methods
    
    private func urlRequest(withEndpoint endpoint: String, andContentLength contentLength: String, andUploadLength uploadLength: String, andFilename fileName: String) -> URLRequest {
        
        var request: URLRequest = URLRequest(url: (uploadURL?.appendingPathComponent(endpoint))!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.addValue("Content-Length", forHTTPHeaderField: contentLength)
        request.addValue("Upload-Length", forHTTPHeaderField: uploadLength)
        request.addValue("Tus-Resumable", forHTTPHeaderField: TUSConstants.TUSProtocolVersion)
        request.addValue("Upload-Metadata", forHTTPHeaderField: fileName)
        
        return request
    }
    
    private func create(forUpload upload: TUSUpload) {
        session.dataTask(with: urlRequest(withEndpoint: "", andContentLength: upload.contentLength!, andUploadLength: upload.uploadLength!, andFilename: upload.id!)) { (data, response, error) in
            //
        }
    }
    
}
