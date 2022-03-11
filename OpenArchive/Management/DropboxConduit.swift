//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftyDropbox
import FilesProvider
import MobileCoreServices

class DropboxConduit: Conduit {

    class func transportClient(unauthorized: Bool) -> DropboxTransportClient? {
        let accessToken = DropboxSpace.space?.password ?? (unauthorized ? "" : nil)

        guard accessToken != nil else {
            return nil
        }

        return DropboxTransportClient(
            accessToken: accessToken!, baseHosts: nil, userAgent: nil, selectUser: nil,
            sessionDelegate: (UIApplication.shared.delegate as? AppDelegate)?.uploadManager,
            backgroundSessionDelegate: Conduit.backgroundSessionManager.delegate,
            sharedContainerIdentifier: Constants.appGroup)
    }

    // MARK: Conduit

    private var client: DropboxClient? {
        if let client = DropboxClientsManager.authorizedClient {
            return client
        }

        if let transportClient = Self.transportClient(unauthorized: false) {
            return DropboxClient(transportClient: transportClient)
        }

        return nil
    }

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

        // As per docs, DropboxClient.files.upload only supports files up until
        // 150 MByte. To avoid, having the user find out after 150 MBytes,
        // we immediately stop this.
        if filesize > 150 * 1024 * 1024 {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: UploadError.dropboxFileTooBig)
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

            DispatchQueue.global(qos: .background).async {
                self.upload(file, to: to, progress)
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
        progress.addChild(p, withPendingUnitCount: 2)

        var done = false

        client?.files.getMetadata(path: folder.path).response { metadata, e in
            if !progress.isCancelled && metadata == nil {
                p.completedUnitCount = 1

                self.client?.files.createFolderV2(path: folder.path).response { result, e in
                    p.completedUnitCount = 2
                    error = NSError.from(e)
                    done = true
                }
            }
            else {
                p.completedUnitCount = 2

                // Does already exist: return.
                done = true
            }
        }

        while !done && !progress.isCancelled {
            Thread.sleep(forTimeInterval: 0.2)
        }

        return error
    }

    /**
     Writes an `Asset`'s metadata to a destination on the Dropbox server.

     - parameter asset: The `Asset` to extract metadata from.
     - parameter to: The destination on the Dropbox server.
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
        var done = false

        upload(json, to: to, progress, 2) { e in
            error = e
            done = true
        }

        while !done && !progress.isCancelled {
            Thread.sleep(forTimeInterval: 0.2)
        }

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

        var done = false

        client?.files.getMetadata(path: path.path).response { metadata, e in
            if let metadata = metadata as? Files.FileMetadata {
                exists = metadata.size == expectedSize
            }
            else {
                exists = false
            }

            done = true
        }

        while !done {
            Thread.sleep(forTimeInterval: 0.2)
        }

        return exists
    }

    /**
     Uploads a file to a destination.

     - parameter file: The file on the local file system.
     - parameter to: The destination on the Dropbox server.
     - parameter progress: The main progress to report on.
     - parameter completionHandler: The callback to call when the copy is done,
     or when an error happened.
     */
    func upload(_ file: URL, to: URL, _ progress: Progress, _ completionHandler: SimpleCompletionHandler = nil) {

        let start = progress.completedUnitCount
        let share = progress.totalUnitCount - start

        client?.files.upload(path: to.path, input: file)
            .progress {
                if progress.isCancelled {
                    $0.cancel()
                }

                progress.completedUnitCount = start + $0.completedUnitCount * share / $0.totalUnitCount
            }
            .response { metadata, error in
                completionHandler?(NSError.from(error))
            }
    }

    func upload(_ data: Data, to: URL, _ progress: Progress, _ share: Int64, _ completionHandler: SimpleCompletionHandler = nil) {

        let start = progress.completedUnitCount

        client?.files.upload(path: to.path, input: data)
            .progress {
                if progress.isCancelled {
                    $0.cancel()
                }

                progress.completedUnitCount = start + $0.completedUnitCount * share / $0.totalUnitCount
            }
            .response { metadata, error in
                completionHandler?(NSError.from(error))
            }
    }
}
