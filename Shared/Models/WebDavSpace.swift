//
//  WebDavSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

/**
 A space supporting WebDAV servers such as Nextcloud/Owncloud.
 */
class WebDavSpace: Space, Item {

    // MARK: Item

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("WebDavSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "WebDavSpace")
    }

    func compare(_ rhs: WebDavSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: WebDavSpace

    private static let metaFileExt = "meta.json"

    private var credential: URLCredential? {
        if let username = username,
            let password = password {

            return URLCredential(user: username, password: password, persistence: .forSession)
        }

        return nil
    }

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `url` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` for this space.
     */
    var provider: WebDAVFileProvider? {
        if let baseUrl = url,
            let credential = credential {

            let provider = WebDAVFileProvider(baseURL: baseUrl, credential: credential)

            let conf = provider?.session.configuration ?? URLSessionConfiguration.default

            conf.sharedContainerIdentifier = Constants.appGroup
            conf.urlCache = provider?.cache
            conf.requestCachePolicy = .returnCacheDataElseLoad

            // Fix error "CredStore - performQuery - Error copying matching creds."
            conf.urlCredentialStorage = nil

            provider?.session = URLSession(configuration: conf,
                                           delegate: provider?.session.delegate,
                                           delegateQueue: provider?.session.delegateQueue)

            return provider
        }

        return nil
    }

    override init(name: String? = nil, url: URL? = nil, favIcon: UIImage? = nil,
                  username: String? = nil, password: String? = nil,
                  authorName: String? = nil, authorRole: String? = nil,
                  authorOther: String? = nil) {

        super.init(name: name, url: url, favIcon: favIcon, username: username,
                   password: password, authorName: authorName,
                   authorRole: authorRole, authorOther: authorOther)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: Space

    override func upload(_ asset: Asset, uploadId: String) -> Progress {

        let progress = Progress.discreteProgress(totalUnitCount: 100)

        guard let projectName = asset.collection.project.name,
            let collectionName = asset.collection.name,
            let file = asset.file,
            let credential = credential
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, InvalidConfError())
            }

            return progress
        }

        let p = create(folder: projectName, at: "") { error in
            if error != nil || progress.isCancelled {
                return self.done(uploadId, error)
            }

            let p = self.create(folder: collectionName, at: projectName) { error in
                if error != nil || progress.isCancelled {
                    return self.done(uploadId, error)
                }

                let to = Space.construct(url: self.url, projectName, collectionName, asset.filename)

                let p = self.copyMetadata(asset, to: to.appendingPathExtension(WebDavSpace.metaFileExt),
                                          credential) { error in

                    if error != nil || progress.isCancelled {
                        return self.done(uploadId, error)
                    }

                    let p = self.upload(file, to: to, credential) { error in
                        self.done(uploadId, error,
                                  Space.construct(url: self.url, projectName,
                                                  collectionName, asset.filename))
                    }

                    progress.addChild(p, withPendingUnitCount: 75)
                }

                progress.addChild(p, withPendingUnitCount: 15)
            }

            progress.addChild(p, withPendingUnitCount: 5)
        }

        progress.addChild(p, withPendingUnitCount: 5)

        return progress
    }

    override func remove(_ asset: Asset, done: @escaping DoneHandler) {
        if let provider = provider,
            let basePath = url?.path,
            let filepath = asset.publicUrl?.path.replacingOccurrences(of: basePath, with: "") {

            provider.removeItem(path: filepath) { error in
                if error == nil {
                    asset.publicUrl = nil
                    asset.isUploaded = false
                }

                provider.removeItem(path: "\(filepath).\(WebDavSpace.metaFileExt)") { error in

                    // Try to delete containing folders until root.
                    self.delete(folder: URL(fileURLWithPath: filepath).deletingLastPathComponent().path) { error in
                        DispatchQueue.main.async {
                            done(asset)
                        }
                    }
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                DispatchQueue.main.async {
                    done(asset)
                }
            }
        }
    }

    /**
     Asynchronously tests, if a folder exists and if not, creates it.

     - parameter folder: Folder name to create.
     - parameter at: Parent path of new folder.
     - parameter completionHandler: Callback, when done.
        If an error was returned, it is from the creation attempt.
    */
    private func create(folder: String, at: String, _ completionHandler: SimpleCompletionHandler) -> Progress {
        let folderpath = URL(fileURLWithPath: at).appendingPathComponent(folder).path

        let progress = Progress(totalUnitCount: 100)

        provider?.attributesOfItem(path: folderpath) { attributes, error in

            if attributes == nil {
                progress.completedUnitCount = 50

                // Does not exist - create.
                if let p = self.provider?.create(folder: folder, at: at, completionHandler: completionHandler) {
                    progress.addChild(p, withPendingUnitCount: 50)
                }
            }
            else {
                progress.completedUnitCount = 100

                // Does exist: continue.
                completionHandler?(nil)
            }
        }

        return progress
    }

    /**
     Writes an `Asset`'s metadata to a temporary file and copies that to the
     destination on the WebDAV server.

     - parameter asset: The `Asset` to extract metadata from.
     - parameter to: The destination on the WebDAV server.
     - parameter credential: The credentials to authenticate with.
     - parameter completionHandler: The callback to call when the copy is done,
       or when an error happened.
     - returns: the progress of the `#copyItem` call or nil, if an error happened.
    */
    private func copyMetadata(_ asset: Asset, to: URL, _ credential: URLCredential,
                              _ completionHandler: SimpleCompletionHandler) -> Progress {

        let progress = Progress(totalUnitCount: 100)
        let fm = FileManager.default

        let tempDir: URL

        do {
            tempDir = try fm.url(for: .itemReplacementDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: asset.file, create: true)
        } catch {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                completionHandler?(error)
            }

            return progress
        }

        let json: Data

        do {
            try json = Space.jsonEncoder.encode(asset)
        }
        catch {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                completionHandler?(error)
            }

            return progress
        }

        let metaFile = tempDir.appendingPathComponent("\(asset.filename).\(WebDavSpace.metaFileExt)")

        do {
            try json.write(to: metaFile, options: .atomicWrite)
        }
        catch {
            try? fm.removeItem(at: metaFile)

            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                completionHandler?(error)
            }

            return progress
        }

        return upload(metaFile, to: to, credential) { error in
            try? fm.removeItem(at: metaFile)

            completionHandler?(error)
        }
    }

    /**
     Uploads a file to a destination.

     This method deliberatly doesn't use the FilesProvder library, but Alamofire
     instead, since FilesProvider's latest version fails on uploading the
     metadata for an unkown reason. Addtionally, it's easier with the background
     upload, when using Alamofire directly.

     - parameter file: The file on the local file system.
     - parameter to: The destination on the WebDAV server.
     - parameter credential: The credentials to authenticate with.
     - parameter completionHandler: The callback to call when the copy is done,
     or when an error happened.
     - returns: the progress of the `#copyItem` call or nil, if an error happened before the actual copy.
    */
    private func upload(_ file: URL, to: URL, _ credential: URLCredential,
                        _ completionHandler: SimpleCompletionHandler) -> Progress {

        let req = sessionManager.upload(file, to: to, method: .put)
            .authenticate(usingCredential: credential)
            .debug()
            .validate(statusCode: 200..<300)
            .responseData() { response in
                completionHandler?(response.error)
            }

        let progress = Progress()
        progress.addChild(req.uploadProgress, withPendingUnitCount: 90)
        progress.addChild(req.progress, withPendingUnitCount: 10)

        return progress
    }

    /**
     Tries to delete parent folders recursively, as long as they are empty.

     - parameter folder: The folder to delete, if empty.
     - parameter completionHandler: Callback, when done.
        If an error was returned, it is from the deletion attempt.
    */
    private func delete(folder: String, _ completionHandler: SimpleCompletionHandler) {
        provider?.contentsOfDirectory(path: folder) { files, error in
            if files.count < 1 {

                // Folder is empty - remove it.
                self.provider?.removeItem(path: folder) { error in

                    // We got an error, stop recursing, return the error.
                    if error != nil {
                        completionHandler?(error)
                    }
                    else {

                        // Go up one higher, try to delete that, too.
                        let parent = URL(fileURLWithPath: folder).deletingLastPathComponent().path

                        if parent != "" && parent != "/" {
                            self.delete(folder: parent, completionHandler)
                        }
                        else {
                            // Stop here, we're can't delete the root.
                            completionHandler?(nil)
                        }
                    }
                }
            }
            else {
                // Folder is not empty - continue.
                completionHandler?(nil)
            }
        }

    }
}
