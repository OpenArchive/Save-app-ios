//
//  WebDavConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

class WebDavConduit: Conduit {

    // MARK: WebDavConduit

    static let metaFileExt = "meta.json"

    private var credential: URLCredential? {
        return (asset.space as? WebDavSpace)?.credential
    }

    private var provider: WebDAVFileProvider? {
        return (asset.space as? WebDavSpace)?.provider
    }

    // MARK: Conduit

    override func upload(uploadId: String) -> Progress {

        let progress = Progress.discreteProgress(totalUnitCount: 100)

        guard let projectName = asset.collection.project.name,
            let collectionName = asset.collection.name,
            let file = asset.file,
            let credential = credential
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: InvalidConfError())
            }

            return progress
        }

        let p = create(folder: projectName, at: "") { error in
            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            let p = self.create(folder: collectionName, at: projectName) { error in
                if error != nil || progress.isCancelled {
                    return self.done(uploadId, error: error)
                }

                let to = Conduit.construct(url: self.asset.space?.url, projectName, collectionName, self.asset.filename)

                let p = self.copyMetadata(self.asset, to: to.appendingPathExtension(WebDavConduit.metaFileExt),
                                          credential) { error in

                    if error != nil || progress.isCancelled {
                        return self.done(uploadId, error: error)
                    }

                    let p = self.check(Conduit.construct(url: nil, projectName, collectionName, self.asset.filename).path) { exists in
                        if progress.isCancelled || exists {
                            return self.done(uploadId, url: to)
                        }

                        self.upload(file, to: to, progress, credential: credential)
                    }

                    progress.addChild(p, withPendingUnitCount: 5)
                }

                progress.addChild(p, withPendingUnitCount: 10)
            }

            progress.addChild(p, withPendingUnitCount: 5)
        }

        progress.addChild(p, withPendingUnitCount: 5)

        return progress
    }

    override func remove(done: @escaping DoneHandler) {
        if let provider = provider,
            let basePath = asset.space?.url?.path,
            let filepath = asset.publicUrl?.path.replacingOccurrences(of: basePath, with: "") {

            provider.removeItem(path: filepath) { error in
                if error == nil {
                    self.asset.setUploaded(nil)
                }

                provider.removeItem(path: "\(filepath).\(WebDavConduit.metaFileExt)") { error in

                    // Try to delete containing folders until root.
                    self.delete(folder: URL(fileURLWithPath: filepath).deletingLastPathComponent().path) { error in
                        DispatchQueue.main.async {
                            done(self.asset)
                        }
                    }
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                DispatchQueue.main.async {
                    done(self.asset)
                }
            }
        }
    }


    // MARK: Private Methods

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
     Checks, if file already exists and is probably the same by comparing the filesize.

     - parameter path: The path to the file on the server.
     - parameter completionHandler: Callback, when done.
     - parameter exists: true, if file exists and size is the same as the asset file.
    */
    private func check(_ path: String, _ completionHandler: ((_ exists: Bool) -> Void)?) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        provider?.attributesOfItem(path: path) { attributes, error in
            let exists = attributes != nil && attributes?.size == self.asset.filesize

            completionHandler?(exists)
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
            try json = Conduit.jsonEncoder.encode(asset)
        }
        catch {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                completionHandler?(error)
            }

            return progress
        }

        let metaFile = tempDir.appendingPathComponent("\(asset.filename).\(WebDavConduit.metaFileExt)")

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

        upload(metaFile, to: to, progress, credential: credential) { error in
            try? fm.removeItem(at: metaFile)

            completionHandler?(error)
        }

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
