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
    static let chunkSize: Int64 = 2 * 1024 * 1024 // 2 MByte
    static let chunkFileSizeThreshold: Int64 = 10 * 1024 * 1024 // 10 MByte

    private var credential: URLCredential? {
        return (asset.space as? WebDavSpace)?.credential
    }

    private var provider: WebDAVFileProvider? {
        return (asset.space as? WebDavSpace)?.provider
    }

    // MARK: Conduit

    override func upload(uploadId: String) -> Progress {

        let progress = Progress.discreteProgress(totalUnitCount: 100)

        guard let projectName = asset.collection?.project.name,
            let collectionName = asset.collection?.name,
            let url = asset.space?.url,
            let file = asset.file,
            let filesize = asset.filesize,
            let credential = credential
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: UploadError.invalidConf)
            }

            return progress
        }

        DispatchQueue.global(qos: .background).async {
            var error = self.create(folder: self.construct(projectName), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            error = self.create(folder: self.construct(projectName, collectionName), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            var path = [projectName, collectionName]

            if self.asset.tags?.contains(Asset.flag) ?? false {
                path.append(Asset.flag)

                error = self.create(folder: self.construct(path), progress)

                if error != nil || progress.isCancelled {
                    return self.done(uploadId, error: error)
                }
            }

            path.append(self.asset.filename)

            let to = self.construct(url: url, path)

            error = self.copyMetadata(self.asset, to: to.appendingPathExtension(WebDavConduit.metaFileExt), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            if self.isUploaded(self.construct(path), filesize) {
                return self.done(uploadId, url: to)
            }

            if progress.isCancelled {
                return self.done(uploadId)
            }

            //Fix to 10% from here, so uploaded bytes can be calculated properly
            // in `UploadCell.upload#didSet`!
            progress.completedUnitCount = 10

            // Use Nextcloud chunking if enabled and file bigger than 10 MByte.
            if self.asset.space?.isNextcloud ?? false,
                let fh = try? FileHandle(forReadingFrom: file),
                filesize > WebDavConduit.chunkFileSizeThreshold {

                self.chunkedUpload(url, credential, uploadId, progress, filesize, fh, path)

                fh.closeFile()
            }
            else {
                DispatchQueue.global(qos: .background).async {
                    self.upload(file, to: to, progress, credential: credential)
                }
            }
        }

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
                    self.delete(folder: self.construct(filepath).deletingLastPathComponent().path) { error in
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
     Tests, if a folder exists and if not, creates it.

     - parameter folder: Folder with path relative to WebDav endpoint.
     - parameter progress: The overall progress object.
     - parameter provider: A `WebDavFileProvider`. Optional. Defaults to `self.provider`.
     If an error was returned, it is from the creation attempt.
     */
    private func create(folder: URL, _ progress: Progress, _ provider: WebDAVFileProvider? = nil) -> Error? {
        guard let provider = provider ?? self.provider else {
            return UploadError.invalidConf
        }

        var error: Error? = nil

        let p = Progress(totalUnitCount: 2)
        progress.addChild(p, withPendingUnitCount: 2)

        let group = DispatchGroup.enter()

        provider.attributesOfItem(path: folder.path) { attributes, e in
            if !progress.isCancelled && attributes == nil {
                p.completedUnitCount = 1

                provider.create(folder: folder.lastPathComponent, at: folder.deletingLastPathComponent().path) { e in
                    p.completedUnitCount = 2
                    error = e
                    group.leave()
                }
            }
            else {
                p.completedUnitCount = 2

                // Does already exist: return.
                group.leave()
            }
        }

        group.wait(signal: progress)

        return error
    }

    /**
     Checks, if file already exists and is probably the same by comparing the filesize.

     - parameter path: The path to the file on the server.
     - parameter expectedSize: The expected size of this file.
     - parameter provider: A `WebDavFileProvider`. Optional. Defaults to `self.provider`.
     - returns: true, if file exists and size is the same as the asset file.
     */
    private func isUploaded(_ path: URL, _ expectedSize: Int64, provider: WebDAVFileProvider? = nil) -> Bool {
        var exists = false

        if let provider = provider ?? self.provider {
            let group = DispatchGroup.enter()

            provider.attributesOfItem(path: path.path) { attributes, error in
                exists = attributes != nil && attributes!.size == expectedSize
                group.leave()
            }

            group.wait()
        }

        return exists
    }

    /**
     Writes an `Asset`'s metadata to a destination on the WebDAV server.

     - parameter asset: The `Asset` to extract metadata from.
     - parameter to: The destination on the WebDAV server.
     - returns: An eventual error.
     */
    private func copyMetadata(_ asset: Asset, to: URL, _ progress: Progress) -> Error? {
        let json: Data

        do {
            try json = Conduit.jsonEncoder.encode(asset)
        }
        catch {
            return error
        }

        var error: Error? = nil
        let group = DispatchGroup.enter()

        upload(json, to: to, progress, 2, credential: credential) { e in
            error = e
            group.leave()
        }

        group.wait(signal: progress)

        return error
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
                        let parent = self.construct(folder).deletingLastPathComponent().path

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

    /**
     Implements [Nextcloud's chunked upload](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/WebDAV/chunking.html).

     This **does not** work with background uploads!

     This most probably will only work with the latest Nextcloud server.
     (Version 16.0.4 when developing)

     - parameter url: The space URL.
     - parameter credential: The space credentials.
     - parameter uploadId: The ID of the upload object which identifies this upload.
     - parameter progress: The progress object to communicate progress with.
     - parameter filesize: The size of the file to upload.
     - parameter fh: An open FileHandle to the file to upload.
     - parameter path: The destination path.
    */
    private func chunkedUpload(_ url: URL, _ credential: URLCredential, _ uploadId: String,
                               _ progress: Progress, _ filesize: Int64, _ fh: FileHandle,
                               _ path: [String]) {

        guard let user = credential.user else {
            return done(uploadId, error: UploadError.invalidConf)
        }

        var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true)
        urlc?.path = "/"

        let baseUrl = construct(url: urlc?.url, "remote.php", "dav")

        let provider = WebDavSpace.createProvider(
            baseUrl: baseUrl, credential: credential)

        let folder = ["uploads", user, asset.filename]

        var error = create(folder: construct(folder), progress, provider)

        if progress.isCancelled || error != nil {
            return done(uploadId, error: error)
        }

        error = nil
        let progressPerChunk = (progress.totalUnitCount - progress.completedUnitCount) / (filesize / WebDavConduit.chunkSize + 1)
        var allThere = false
        var round = 1

        // We loop at least 2 times:
        // 1st: upload all chunks, one after the other.
        // 2nd: Check, if al chunks are available. If not, upload missing chunks.
        // Repeat until all chunks are uploaded correctly.
        // Fail after 10 retries.

        repeat {
            allThere = true
            var offset: Int64 = 0

            while offset < filesize {
                let expectedSize = min(WebDavConduit.chunkSize, filesize - offset)

                var dest = folder
                dest.append(String(format: "%015d-%015d", offset, offset + expectedSize - 1))

                let exists = isUploaded(construct(dest), expectedSize, provider: provider)

                if progress.isCancelled {
                    return done(uploadId)
                }

                offset += expectedSize

                if exists {
                    fh.seek(toFileOffset: UInt64(offset))

                    // Only increase the first time, otherwise we would exceed 100%.
                    // (First time could be after an app restart.)
                    if round == 1 {
                        progress.completedUnitCount += progressPerChunk
                    }
                }
                else {
                    allThere = false

                    // Deduct progress again, since, obviously, this wasn't successfully
                    // uploaded on the last try.
                    if round > 1 {
                        progress.completedUnitCount -= progressPerChunk
                    }

                    let chunk = fh.readData(ofLength: Int(expectedSize))

                    let group = DispatchGroup.enter()

                    upload(chunk, to: construct(url: baseUrl, dest), progress, progressPerChunk, credential: credential) { e in
                        error = e
                        group.leave()
                    }

                    // Synchronize asynchronous call.
                    group.wait(signal: progress)

                    if progress.isCancelled || error != nil {
                        break
                    }
                }
            }

            if progress.isCancelled || error != nil {
                break
            }

            if round > 9 {
                error = UploadError.invalidConf
                break
            }

            round += 1

        } while !allThere

        if progress.isCancelled || error != nil {
            return done(uploadId, error: error)
        }

        var source = folder
        source.append(".file")

        var dest = ["files", user]
        dest.append(contentsOf: path)

        provider?.moveItem(path: construct(source).path, to: construct(dest).path) { error in
            progress.completedUnitCount = progress.totalUnitCount
            self.done(uploadId, url: self.construct(url: url, path))
        }
    }
}
