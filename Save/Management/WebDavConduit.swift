//
//  WebDavConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class WebDavConduit: Conduit {

    // MARK: WebDavConduit

    private var credential: URLCredential? {
        return (asset.space as? WebDavSpace)?.credential
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
            var path = [projectName]

            var error = self.create(folder: self.construct(url: url, path), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            path.append(collectionName)

            error = self.create(folder: self.construct(url: url, path), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            if self.asset.tags?.contains(Asset.flag) ?? false {
                path.append(Asset.flag)

                error = self.create(folder: self.construct(url: url, path), progress)

                if error != nil || progress.isCancelled {
                    return self.done(uploadId, error: error)
                }
            }

            path.append(self.asset.filename)

            let to = self.construct(url: url, path)

            error = self.copyMetadata(self.asset, to: to.appendingPathExtension(Conduit.metaFileExt), progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            if self.isUploaded(self.construct(url: url, path), filesize) {
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
                filesize > Conduit.chunkFileSizeThreshold
            {
                self.chunkedUpload(url, credential, uploadId, progress, file, of: filesize, path)
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
        if let publicUrl = asset.publicUrl {
            foregroundSession.delete(publicUrl, credential: credential) { error in
                if error == nil {
                    self.asset.setUploaded(nil)
                }

                self.foregroundSession.delete(publicUrl.appendingPathExtension(Conduit.metaFileExt), credential: self.credential) { error in

                    // Try to delete containing folders until root.
                    self.delete(folder: publicUrl.deletingLastPathComponent()) { error in
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
     Creates folder, if it doesn't exist, yet.

     - parameter folder: Folder with path relative to WebDav endpoint.
     - parameter progress: The overall progress object.
     - returns: An error or `nil` on success.
     */
    private func create(folder: URL, _ progress: Progress) -> Error? {
        var error: Error? = nil

        let group = DispatchGroup.enter()

        let task = foregroundSession.mkDir(folder, credential: credential) { e in
            if case SaveError.http(let status)? = e, status == 405 {
                // That's ok, that just means that the folder already exists.
            }
            else {
                error = e
            }

            group.leave()
        }

        progress.addChild(task.progress, withPendingUnitCount: 2)

        group.wait(signal: progress)

        return error
    }

    /**
     Checks, if file already exists and is probably the same by comparing the filesize.

     - parameter path: The path to the file on the server.
     - parameter expectedSize: The expected size of this file.
     - returns: true, if file exists and size is the same as the asset file.
     */
    private func isUploaded(_ path: URL, _ expectedSize: Int64) -> Bool {
        var exists = false

        let group = DispatchGroup.enter()

        foregroundSession.info(path, credential: credential) { info, error in
            exists = info.first != nil && info.first!.size == expectedSize
            group.leave()
        }

        group.wait()

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
    private func delete(folder: URL, _ completionHandler: URLSession.SimpleCompletionHandler?) {
        foregroundSession.info(folder, credential: credential) { info, error in
            if info.count < 2 {

                // Folder is empty - remove it.
                self.foregroundSession.delete(folder, credential: self.credential) { error in

                    // We got an error, stop recursing, return the error.
                    if error != nil {
                        completionHandler?(error)
                    }
                    else {

                        // Go up one higher, try to delete that, too.
                        let parent = folder.deletingLastPathComponent()

                        if parent.path != "" && parent.path != "/" {
                            self.delete(folder: parent, completionHandler)
                        }
                        else {
                            // Stop here, we can't delete the root.
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
                               _ progress: Progress, _ file: URL, of filesize: Int64,
                               _ path: [String])
    {
        guard let user = credential.user else {
            return done(uploadId, error: UploadError.invalidConf)
        }

        var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true)
        urlc?.path = "/"

        let baseUrl = construct(url: urlc?.url, "remote.php", "dav")

        let folder = ["uploads", user, asset.filename]

        var error = create(folder: construct(url: baseUrl, folder), progress)

        if progress.isCancelled || error != nil {
            return done(uploadId, error: error)
        }

        error = nil
        let progressPerChunk = (progress.totalUnitCount - progress.completedUnitCount) / (filesize / Conduit.chunkSize + 1)
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
                let expectedSize = min(Conduit.chunkSize, filesize - offset)

                var dest = folder
                dest.append(String(format: "%015d-%015d", offset, offset + expectedSize - 1))

                let exists = isUploaded(construct(url: baseUrl, dest), expectedSize)

                if progress.isCancelled {
                    return done(uploadId)
                }

                offset += expectedSize

                if exists {
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

                    let chunk: Data

                    do {
                        chunk = try Conduit.readChunk(file, offset: UInt64(offset), length: expectedSize)
                    }
                    catch let e {
                        error = e
                        break
                    }

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

        let task = foregroundSession.move(construct(url: baseUrl, source), to: construct(url: baseUrl, dest), credential: credential)
        { error in
                self.done(uploadId, url: self.construct(url: url, path))
        }

        progress.addChild(task.progress, withPendingUnitCount: progress.totalUnitCount - progress.completedUnitCount)
    }
}
