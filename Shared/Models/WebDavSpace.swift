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

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `url` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` for this space.
     */
    var provider: WebDAVFileProvider? {
        if let username = username,
            let password = password,
            let baseUrl = url {

            let credential = URLCredential(user: username, password: password, persistence: .forSession)

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

        guard let provider = provider,
            let projectName = asset.collection.project.name,
            let collectionName = asset.collection.name,
            let file = asset.file
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, "Configuration invalid.".localize())
            }

            return progress
        }

        create(folder: projectName, at: "") { error in
            if error != nil || progress.isCancelled {
                return self.done(uploadId, error)
            }

            progress.completedUnitCount += 5

            self.create(folder: collectionName, at: projectName) { error in
                if error != nil || progress.isCancelled {
                    return self.done(uploadId, error)
                }

                progress.completedUnitCount += 5

                let filepath = Space.construct(url: nil, projectName, collectionName, asset.filename).path

                let p = provider.writeContents(path: "\(filepath).\(WebDavSpace.metaFileExt)",
                    contents: try? Space.jsonEncoder.encode(asset)) { error in
                        if error != nil || progress.isCancelled {
                            return self.done(uploadId, error)
                        }

                        // Inject our own background session, so upload can finish, when
                        // user quits app.
                        // This can only be done on upload, we would get an error on
                        // deletion.
                        let conf = Space.sessionConf
                        conf.urlCache = provider.cache
                        conf.requestCachePolicy = .returnCacheDataElseLoad

                        let sessionDelegate = SessionDelegate(fileProvider: provider)

                        // Store for later re-set.
                        let oldSession = provider.session

                        provider.session = URLSession(configuration: conf,
                                                      delegate: sessionDelegate as URLSessionDelegate?,
                                                      delegateQueue: provider.operation_queue)

                        let p = provider.copyItem(localFile: file, to: filepath) { error in
                            // Reset to normal session, so #remove doesn't break.
                            provider.session = oldSession

                            self.done(uploadId, error?.localizedDescription,
                                      Space.construct(url: self.url, projectName,
                                                      collectionName, asset.filename))
                        }

                        if let p = p {
                            progress.addChild(p, withPendingUnitCount: 75)
                        }
                }

                if let p = p {
                    progress.addChild(p, withPendingUnitCount: 15)
                }
            }
        }

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
    private func create(folder: String, at: String, _ completionHandler: SimpleCompletionHandler) {
        let folderpath = URL(fileURLWithPath: at).appendingPathComponent(folder).path

        provider?.attributesOfItem(path: folderpath) { attributes, error in

            if attributes == nil {
                // Does not exist - create.
                self.provider?.create(folder: folder, at: at, completionHandler: completionHandler)
            }
            else {
                // Does exist: continue.
                completionHandler?(nil)
            }
        }
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
