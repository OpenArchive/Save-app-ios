//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftyDropbox
import MobileCoreServices

class DropboxConduit: Conduit {

    class func transportClient(unauthorized: Bool) -> DropboxTransportClient? {
        guard let accessToken = DropboxSpace.space?.password ?? (unauthorized ? "" : nil) else {
            return nil
        }

        return DropboxTransportClient(
            accessToken: accessToken, baseHosts: nil, userAgent: nil, selectUser: nil,
            config: URLSession.improvedConf())
    }

    class var client: DropboxClient? {
        if let client = DropboxClientsManager.authorizedClient {
            return client
        }

        if let transportClient = transportClient(unauthorized: false) {
            return DropboxClient(transportClient: transportClient)
        }

        return nil
    }


    // MARK: Conduit

    /**
     */
    override func upload(uploadId: String) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        guard let projectName = asset.collection?.project.name,
            let collectionName = asset.collection?.name,
            let filesize = asset.filesize,
            let file = asset.file
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

            let to = self.construct(path)

            error = self.copyMetadata(to: to, progress)

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

            DispatchQueue.global(qos: .background).async {
                self.upload(file, of: filesize, to: to, progress) { error in
                    self.done(uploadId, error: error, url: to)
                }
            }
        }

        return progress
    }

    override func remove(done: @escaping DoneHandler) {
    }


    // MARK: Private Methods

    /**
     Tests, if a folder exists and if not, creates it.

     - parameter folder: Folder with path relative to WebDav endpoint.
     - parameter progress: The overall progress object.
     - parameter provider: A `WebDavFileProvider`. Optional. Defaults to `self.provider`.
     If an error was returned, it is from the creation attempt.
     */
    private func create(folder: URL, _ progress: Progress) -> Error? {
        var error: Error? = nil

        let p = Progress(totalUnitCount: 2)
        progress.addChild(p, withPendingUnitCount: 1)

        let group = DispatchGroup.enter()

        Self.client?.files.getMetadata(path: folder.path).response { metadata, e in
            if !progress.isCancelled && metadata == nil {
                p.completedUnitCount = 1

                Self.client?.files.createFolderV2(path: folder.path).response { result, e in
                    p.completedUnitCount = 2
                    error = NSError.from(e)
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
     Writes an `Asset`'s metadata to a destination on the Dropbox server.

     - parameter to: The destination on the Dropbox server.
     - returns: An eventual error.
     */
    private func copyMetadata(to: URL, _ progress: Progress) -> Error? {
        let json: Data

        do {
            try json = Conduit.jsonEncoder.encode(asset)
        }
        catch {
            return error
        }

        var error: Error? = nil
        let group = DispatchGroup.enter()

        upload(json, to: to.appendingPathExtension(Asset.Files.meta.rawValue), progress, 1) { e in
            if error == nil && e != nil {
                error = e
            }

            group.leave()
        }

        group.wait(signal: progress)

        if error != nil || progress.isCancelled {
            return error
        }

        uploadProofMode { file, ext in
            guard let size = file.size else {
                return true
            }

            group.enter()

            upload(file, of: Int64(size), to: to.appendingPathExtension(ext), progress, pendingUnitCount: 1) { e in
                if error == nil && e != nil {
                    error = e
                }

                group.leave()
            }

            group.wait(signal: progress)

            return error == nil && !progress.isCancelled
        }

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

        Self.client?.files.getMetadata(path: path.path).response { metadata, e in
            if let metadata = metadata as? Files.FileMetadata {
                exists = metadata.size == expectedSize
            }
            else {
                exists = false
            }

            group.leave()
        }

        group.wait()

        return exists
    }

    /**
     Uploads a file to a destination.

     - parameter file: The file on the local file system.
     - parameter filesize: The total size of the file.
     - parameter to: The destination on the Dropbox server.
     - parameter progress: The main progress to report on.
     - parameter completionHandler: The callback to call when the copy is done,
     or when an error happened.
     */
    func upload(_ file: URL, of filesize: Int64, to: URL, _ progress: Progress, pendingUnitCount: Int64? = nil,
                _ completionHandler: URLSession.SimpleCompletionHandler? = nil)
    {
        let pendingUnitCount = pendingUnitCount ?? (progress.totalUnitCount - progress.completedUnitCount)

        if filesize > Conduit.chunkFileSizeThreshold {
            let expectedSize = min(Conduit.chunkSize, filesize)
            let chunk: Data

            do {
                chunk = try Conduit.readChunk(file, offset: 0, length: expectedSize)
            }
            catch {
                completionHandler?(error)

                return
            }

            let progressPerChunk = pendingUnitCount / (filesize / Conduit.chunkSize + 1)

            Self.client?.files.uploadSessionStart(input: chunk)
                .progress(progressHandler(progress: progress, addWithCount: progressPerChunk))
                .response { [weak self] result, error in
                    if let result = result {
                        self?.uploadNextChunk(file, of: filesize, to: to, result.sessionId,
                                              UInt64(expectedSize), progress, progressPerChunk, completionHandler)

                        return
                    }

                    completionHandler?(NSError.from(error))
                }
        }
        else {
            Self.client?.files.upload(path: to.path, input: file)
                .progress(progressHandler(progress: progress, addWithCount: pendingUnitCount))
                .response { metadata, error in
                    completionHandler?(NSError.from(error))
                }
            }
    }

    func upload(_ data: Data, to: URL, _ progress: Progress, _ share: Int64, _ completionHandler: URLSession.SimpleCompletionHandler? = nil) {
        Self.client?.files.upload(path: to.path, input: data)
            .progress(progressHandler(progress: progress, addWithCount: share))
            .response { metadata, error in
                completionHandler?(NSError.from(error))
            }
    }


    // MARK: Private Methods

    private func uploadNextChunk(_ file: URL, of filesize: Int64, to: URL, _ sessionId: String, _ offset: UInt64, _ progress: Progress, _ progressPerChunk: Int64, _ completionHandler: URLSession.SimpleCompletionHandler?) {

        let expectedSize = min(Conduit.chunkSize, filesize - Int64(offset))
        let chunk: Data

        do {
            chunk = try Conduit.readChunk(file, offset: offset, length: expectedSize)
        }
        catch {
            completionHandler?(error)

            return
        }

        let cursor = Files.UploadSessionCursor(sessionId: sessionId, offset: offset)

        if Int64(offset) + expectedSize >= filesize {
            Self.client?.files.uploadSessionFinish(cursor: cursor, commit: Files.CommitInfo(path: to.path), input: chunk)
                .progress(progressHandler(progress: progress, addWithCount: progressPerChunk))
                .response { metadata, error in
                    completionHandler?(NSError.from(error))
                }
        }
        else {
            Self.client?.files.uploadSessionAppendV2(cursor: cursor, input: chunk)
                .progress(progressHandler(progress: progress, addWithCount: progressPerChunk))
                .response { [weak self] _, error in
                    if let error = error {
                        completionHandler?(NSError.from(error))
                    }
                    else {
                        self?.uploadNextChunk(file, of: filesize, to: to, sessionId, offset + UInt64(expectedSize), progress, progressPerChunk, completionHandler)
                    }
                }
        }
    }

    private func progressHandler(progress: Progress, addWithCount count: Int64) -> ((Progress) -> Void) {
        var progressAdded = false

        return {
            if progress.isCancelled {
                $0.cancel()
            }

            if !progressAdded {
                progress.addChild($0, withPendingUnitCount: count)
                progressAdded = true
            }
        }
    }
}
