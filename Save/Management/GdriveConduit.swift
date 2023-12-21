//
//  GdriveConduit.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

/**
 Google Drive's speciality is, that every file and folder has unique IDs. Nothing is overwritten, so we always have to check
 if a file exists or not before trying to upload anything.

 If a file exists but has the wrong size then we need to delete the old one.
 */
class GdriveConduit: Conduit {

    static let folderMimeType = "application/vnd.google-apps.folder"

    static var user: GIDGoogleUser? = nil

    class var service: GTLRDriveService {
        let service = GTLRDriveService()
        service.authorizer = user?.fetcherAuthorizer

        return service
    }

    class func list(type: String? = nil, filter name: String? = nil, parentId: String? = nil,
                    completion: ((_ files: [GTLRDrive_File], _ error: Error?) -> Void)?)
    {
        let query = GTLRDriveQuery_FilesList.query()
        query.spaces = "drive"
        query.corpora = "user,allTeamDrives"
        query.q = "trashed=false"
        query.includeItemsFromAllDrives = true
        query.supportsAllDrives = true
        query.orderBy = "name_natural"
        query.pageSize = 999
        query.fields = "files(id,name,mimeType,modifiedTime,createdTime,size,parents)"

        if let type = type, !type.isEmpty {
            query.q?.append(" AND mimeType='\(type)'")
        }

        if let name = name, !name.isEmpty {
            query.q?.append(" AND name='\(name)'")
        }

        if let parentId = parentId, !parentId.isEmpty {
            query.q?.append(" AND '\(parentId)' in parents")
        }

        service.executeQuery(query) { _, result, error in
            completion?((result as? GTLRDrive_FileList)?.files ?? [], error)
        }
    }


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
            var parentId = ""
            var path = [String]()

            var result = self.create(folder: projectName, progress)

            guard let fileId = result.file?.identifier,
                  !fileId.isEmpty && result.error == nil && !progress.isCancelled
            else {
                return self.done(uploadId, error: result.error)
            }

            parentId = fileId
            path.append(projectName)

            result = self.create(folder: collectionName, parentId: parentId, progress)

            guard let fileId = result.file?.identifier,
                  !fileId.isEmpty && result.error == nil && !progress.isCancelled
            else {
                return self.done(uploadId, error: result.error)
            }

            parentId = fileId
            path.append(collectionName)

            if self.asset.tags?.contains(Asset.flag) ?? false {
                result = self.create(folder: Asset.flag, parentId: parentId, progress)

                guard let fileId = result.file?.identifier,
                      !fileId.isEmpty && result.error == nil && !progress.isCancelled
                else {
                    return self.done(uploadId, error: result.error)
                }

                parentId = fileId
                path.append(Asset.flag)
            }

            let error = self.copyMetadata(to: parentId, progress)

            if error != nil || progress.isCancelled {
                return self.done(uploadId, error: error)
            }

            path.append(self.asset.filename)
            let to = self.construct(path)

            if self.isUploaded(self.asset.filename, parentId: parentId, filesize) {
                return self.done(uploadId, url: to)
            }

            if progress.isCancelled {
                return self.done(uploadId)
            }

            //Fix to 10% from here, so uploaded bytes can be calculated properly
            // in `UploadCell.upload#didSet`!
            progress.completedUnitCount = 10

            DispatchQueue.global(qos: .background).async {
                self.upload(file, of: filesize, name: self.asset.filename, type: self.asset.mimeType, parentId: parentId, progress)
                { error in
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

     - parameter folder: Folder name.
     - parameter parentId: The destination folder ID on the Google Drive server or `nil` for the root folder.
     - parameter progress: The overall progress object.
     If an error was returned, it is from the creation attempt.
     */
    private func create(folder: String, parentId: String? = nil, _ progress: Progress) -> (file: GTLRDrive_File?, error: Error?) {
        var file: GTLRDrive_File? = nil
        var error: Error? = nil

        let p = Progress(totalUnitCount: 2)
        progress.addChild(p, withPendingUnitCount: 1)

        let group = DispatchGroup.enter()

        Self.list(type: Self.folderMimeType, filter: folder, parentId: parentId) { files, e in
            file = files.first { $0.name == folder }

            if !progress.isCancelled && e == nil && file == nil {
                p.completedUnitCount = 1

                let f = GTLRDrive_File()
                f.mimeType = Self.folderMimeType
                f.name = folder

                if let parentId = parentId, !parentId.isEmpty {
                    f.parents = [parentId]
                }

                let query = GTLRDriveQuery_FilesCreate.query(withObject: f, uploadParameters: nil)

                Self.service.executeQuery(query) { _, result, e in
                    p.completedUnitCount = 2

                    file = result as? GTLRDrive_File
                    error = e

                    group.leave()
                }
            }
            else {
                p.completedUnitCount = 2

                error = e

                // Does already exist: return.
                group.leave()
            }
        }

        group.wait(signal: progress)

        return (file, error)
    }

    /**
     Writes an `Asset`'s metadata to a destination on the Google Drive server.

     - parameter parentId: The destination folder ID on the Google Drive server.
     - returns: An eventual error.
     */
    private func copyMetadata(to parentId: String, _ progress: Progress) -> Error? {
        let json: Data

        do {
            try json = Conduit.jsonEncoder.encode(asset)
        }
        catch {
            return error
        }

        let group = DispatchGroup()
        var error: Error? = nil

        let to = construct(asset.filename).appendingPathExtension(Asset.Files.meta.rawValue)

        if !isUploaded(to.lastPathComponent, parentId: parentId, Int64(json.count)) {
            group.enter()

            upload(json, name: to.lastPathComponent, type: Asset.Files.meta.mimeType,
                   parentId: parentId, progress, pendingUnitCount: 1)
            { e in
                error = e

                group.leave()
            }

            group.wait(signal: progress)
        }

        if error != nil || progress.isCancelled {
            return error
        }

        uploadProofMode { source, name, type in
            guard let size = source.size else {
                return true
            }

            if !isUploaded(name, parentId: parentId, Int64(size)) {
                group.enter()

                upload(source, of: Int64(size), name: name, type: type, parentId: parentId, progress, pendingUnitCount: 1) { e in
                    error = e

                    group.leave()
                }

                group.wait(signal: progress)
            }

            return error == nil && !progress.isCancelled
        }

        return error
    }


    /**
     Uploads ProofMode files, if ProofMode is enabled and files are available for the current asset.

     - parameter upload: Callback which implements the actual upload of a file, which differs depending on the actual conduit. Return `true` to continue or `false` to stop.
     - parameter source: The URL of the file to upload.
     - parameter name: The destination file name.
     */
    private func uploadProofMode(_ upload: (_ source: URL, _ name: String, _ type: String) -> Bool) {
        guard Settings.proofMode,
              let publicKeyFile = URL.proofModePublicKey,
              publicKeyFile.exists,
              upload(publicKeyFile, publicKeyFile.lastPathComponent, Asset.Files.signature.mimeType)
        else {
            return
        }

        for file in Asset.Files.allCases {
            guard file.isProof else {
                continue
            }

            if let url = file.url(asset.id), url.exists {
                if !upload(url, 
                           construct(asset.filename).appendingPathExtension(file.rawValue).lastPathComponent,
                           file.mimeType
                ) {
                    break
                }
            }
        }
    }


    /**
     Checks, if file already exists and is probably the same by comparing the filesize.

     ATTENTION: There is a side-effect: If a file exists but has the wrong size, it will be deleted.
     Otherwise, Google Drive would make copies, as Google Drive uses internal IDs instead of the file name as unique identifiers.

     - parameter name: The name of  the file on the server.
     - parameter parentId: The destination folder ID on the Google Drive server.
     - parameter expectedSize: The expected size of this file.
     - returns: true, if file exists and size is the same as the asset file.
     */
    private func isUploaded(_ name: String, parentId: String, _ expectedSize: Int64) -> Bool {
        var result = false
        let group = DispatchGroup.enter()

        Self.list(filter: name, parentId: parentId) { files, _ in
            let files = files.filter({ $0.name == name })

            let goodFile = files.first(where: { $0.size?.int64Value == expectedSize })
            result = goodFile != nil

            for file in files {
                if file != goodFile, let id = file.identifier, !id.isEmpty {
                    group.enter()

                    let query = GTLRDriveQuery_FilesDelete.query(withFileId: id)

                    Self.service.executeQuery(query) { _, _, _ in
                        group.leave()
                    }
                }
            }

            group.leave()
        }

        group.wait()

        return result
    }

    /**
     Uploads a file to a destination.

     - parameter file: The file on the local file system.
     - parameter filesize: The total size of the file.
     - parameter name: The name of  the file on the server.
     - parameter type: The MIME type of the file.
     - parameter parentId: The destination folder ID on the Google Drive server.
     - parameter progress: The main progress to report on.
     - parameter completionHandler: The callback to call when the copy is done,
     or when an error happened.
     */
    private func upload(_ file: URL, of filesize: Int64, 
                        name: String, type: String, parentId: String,
                        _ progress: Progress, pendingUnitCount: Int64? = nil,
                        _ completion: URLSession.SimpleCompletionHandler? = nil)
    {
        let params = GTLRUploadParameters(fileURL: file, mimeType: type)

        upload(params, filesize, name, type, parentId, progress, pendingUnitCount, completion)
    }

    /**
     Uploads content to a destination.

     - parameter data: The content to upload.
     - parameter name: The name of  the file on the server.
     - parameter type: The MIME type of the content.
     - parameter parentId: The destination folder ID on the Google Drive server.
     - parameter progress: The main progress to report on.
     - parameter completionHandler: The callback to call when the copy is done,
     or when an error happened.
     */
    private func upload(_ data: Data, name: String, type: String, parentId: String,
                        _ progress: Progress, pendingUnitCount: Int64? = nil,
                        _ completion: URLSession.SimpleCompletionHandler? = nil)
    {
        let params = GTLRUploadParameters(data: data, mimeType: type)

        upload(params, Int64(data.count), name, type, parentId, progress, pendingUnitCount, completion)
    }

    private func upload(_ params: GTLRUploadParameters, _ size: Int64,
                        _ name: String, _ type: String, _ parentId: String,
                        _ progress: Progress, _ pendingUnitCount: Int64?,
                        _ completion: URLSession.SimpleCompletionHandler?)
    {
        let pendingUnitCount = pendingUnitCount ?? (progress.totalUnitCount - progress.completedUnitCount)

        let p = Progress(totalUnitCount: size)
        progress.addChild(p, withPendingUnitCount: pendingUnitCount)

        let f = GTLRDrive_File()
        f.name = name
        f.mimeType = type
        f.parents = [parentId]

        let query = GTLRDriveQuery_FilesCreate.query(withObject: f, uploadParameters: params)

        Self.service.uploadProgressBlock = { _, uploaded, total in
            p.completedUnitCount = Int64(uploaded)
            p.totalUnitCount = Int64(total)
        }

        Self.service.executeQuery(query) { _, result, error in
            Self.service.uploadProgressBlock = nil
            completion?(error)
        }
    }
}
