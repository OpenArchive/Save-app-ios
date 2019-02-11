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

    override init(_ name: String? = nil, _ url: URL? = nil, _ username: String? = nil, _ password: String? = nil) {
        super.init(name, url, username, password)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: Space

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {

        let collection = asset.collection

        guard let projectName = collection.project.name,
            let provider = provider,
            let file = asset.file
        else {
            return self.done(asset, "Optionals could not be unpacked.", done)
        }

        collection.close()

        guard let collectionName = collection.name else {
            return self.done(asset, "Collection name could not be created.", done)
        }

        // Send an initial empty progress, to trigger some UI feedback.
        // Folder creation can take a while.
        progress(asset, Progress.discreteProgress(totalUnitCount: 100))

        create(folder: projectName, at: "") { error in
            if let error = error {
                return self.done(asset, error.localizedDescription, done)
            }

            self.create(folder: collectionName, at: projectName) { error in

                if let error = error {
                    return self.done(asset, error.localizedDescription, done)
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

                var timer: DispatchSourceTimer?

                let filepath = self.construct(url: nil, projectName, collectionName, asset.filename).path

                let prog = provider.copyItem(localFile: file, to: filepath) { error in
                    if error == nil {
                        asset.publicUrl = self.construct(url: self.url, projectName, collectionName, asset.filename)
                        asset.isUploaded = true
                        collection.setUploadedNow()
                    }

                    timer?.cancel()

                    // Reset to normal session, so #remove doesn't break.
                    provider.session = oldSession

                    self.done(asset, error?.localizedDescription, done)
                }

                if let prog = prog {
                    timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.main)
                    timer?.schedule(deadline: .now(), repeating: .seconds(1))
                    timer?.setEventHandler() {
                        // For an uninvestigated reason, this progress counter runs until 200%, which looks
                        // kind of weird to the user, so we scale it down, here.
                        let scaledProgress = Progress(totalUnitCount: prog.totalUnitCount)
                        scaledProgress.completedUnitCount = prog.completedUnitCount / 2

                        progress(asset, scaledProgress)

                        if scaledProgress.isCancelled {
                            prog.cancel()
                        }
                    }
                    timer?.resume()
                }
            }
        }
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

                // Try to delete containing folders until root.
                self.delete(folder: URL(fileURLWithPath: filepath).deletingLastPathComponent().path) { error in
                    self.done(asset, error?.localizedDescription, done)
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                self.done(asset, nil, done)
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
