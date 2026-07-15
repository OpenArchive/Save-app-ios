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

    private static var knownFolders = Set<URL>()
    private static let knownFoldersLock = NSLock()

    static func clearFolderCache() {
        knownFoldersLock.lock()
        knownFolders.removeAll()
        knownFoldersLock.unlock()
    }

    /// Creates project/collection (and flag) folders while still in the foreground so background
    /// uploads can skip blocking `mkDir` calls on a suspended foreground URLSession.
    @discardableResult
    static func prepareCollectionFolders(
        for asset: Asset,
        session: URLSession,
        credential: URLCredential?,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        guard let projectName = asset.collection?.project.name,
              let collectionName = asset.collection?.name,
              let baseUrl = asset.space?.url,
              let credential
        else {
            return false
        }

        var path = [projectName]
        var folders = [Conduit.construct(url: baseUrl, path)]

        path.append(collectionName)
        folders.append(Conduit.construct(url: baseUrl, path))

        if asset.tags?.contains(Asset.flag) ?? false {
            path.append(Asset.flag)
            folders.append(Conduit.construct(url: baseUrl, path))
        }

        for folder in folders {
            knownFoldersLock.lock()
            let alreadyKnown = knownFolders.contains(folder)
            knownFoldersLock.unlock()

            if alreadyKnown {
                continue
            }

            var error: Error?
            let group = DispatchGroup()
            group.enter()

            let start = Date()
            _ = session.mkDir(folder, credential: credential) { e in
                if case SaveError.http(let status)? = e, status == 405 {
                    // Folder already exists.
                } else {
                    error = e
                }
                group.leave()
            }

            // Wait with timeout to prevent blocking forever
            let result = group.wait(timeout: .now() + timeout)

            if result == .timedOut {
                #if DEBUG
                print("[WebDavConduit] mkdir timeout folder=\(folder) — skipping")
                #endif
                // Don't fail entire prep, continue to next folder
                continue
            }

            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 2.0 {
                #if DEBUG
                print("[WebDavConduit] mkdir slow (\(String(format: "%.1f", elapsed))s) folder=\(folder)")
                #endif
            }

            // Check if mkdir failed (excluding 405 which means folder exists)
            if error != nil {
                #if DEBUG
                print("[WebDavConduit] prepareCollectionFolders failed for \(folder): \(error)")
                #endif
                return false
            }

            knownFoldersLock.lock()
            knownFolders.insert(folder)
            knownFoldersLock.unlock()
        }

        return true
    }

    private var credential: URLCredential? {
        return (asset.space as? WebDavSpace)?.credential
    }
    
    // MARK: Conduit
    
    override func upload(uploadId: String) -> Progress {
        
        let progress = Progress.discreteProgress(totalUnitCount: 100)
        UploadManager.shared.attachLiveProgress(progress, for: uploadId)

        guard let projectName = asset.collection?.project.name,
              let collectionName = asset.collection?.name,
              let url = asset.space?.url,
              let file = asset.file,
              FileManager.default.fileExists(atPath: file.path),
              let filesize = asset.filesize,
              let credential = credential
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: UploadError.invalidConf)
            }

            return progress
        }

        var path = [projectName]

        #if DEBUG
        let inBg = WebDavUploadManager.shared.isEffectivelyBackgrounded
        print("[WebDavConduit] upload begin id=\(uploadId) file=\(asset.filename) inBackground=\(inBg)")
        #endif

        var error = create(folder: construct(url: url, path), progress, label: "project")

        if error != nil || progress.isCancelled {
            done(uploadId, error: error)
            return progress
        }

        path.append(collectionName)

        error = create(folder: construct(url: url, path), progress, label: "collection")

        if error != nil || progress.isCancelled {
            done(uploadId, error: error)
            return progress
        }

        //only generate proof for system camera images
        let hasPHAsset = asset.phAsset != nil
        if asset.tags?.contains(Asset.flag) ?? false {
            path.append(Asset.flag)

            error = create(folder: construct(url: url, path), progress, label: "flag")

            if error != nil || progress.isCancelled {
                done(uploadId, error: error)
                return progress
            }
        }

        error = copyMetadata(to: construct(url: url, path), progress, hasPhAsset: hasPHAsset)

        if error != nil || progress.isCancelled {
            done(uploadId, error: error)
            return progress
        }

        path.append(asset.filename)

        let to = construct(url: url, path)

        let inBackground = WebDavUploadManager.shared.isEffectivelyBackgrounded
        if !inBackground && isUploaded(to, filesize) {
            #if DEBUG
            print("[WebDavConduit] skip file already on server file=\(asset.filename)")
            #endif
            done(uploadId, url: to)
            return progress
        }

        if inBackground {
            #if DEBUG
            print("[WebDavConduit] skip isUploaded check (background) file=\(asset.filename)")
            #endif
        }

        if progress.isCancelled {
            done(uploadId)
            return progress
        }

        //Fix to 10% from here, so uploaded bytes can be calculated properly
        // in `UploadCell.upload#didSet`!
        progress.completedUnitCount = 10

        // Use Nextcloud chunking if enabled and file bigger than 10 MByte.
        let useChunking = (asset.space?.isNextcloud ?? false)
            && filesize > Conduit.chunkFileSizeThreshold
        #if DEBUG
        print("[WebDavConduit] upload path file=\(asset.filename) sizeKB=\(filesize / 1024) isNextcloud=\(asset.space?.isNextcloud ?? false) chunked=\(useChunking)")
        #endif
        #if DEBUG
        print("[WebDavConduit] prep done file=\(asset.filename) → background PUT url=\(to.absoluteString)")
        #endif
        if useChunking {
            chunkedUpload(url, credential, uploadId, progress, file, of: filesize, path)
        }
        else {
            upload(file, to: to, progress, credential: credential)
        }

        return progress
    }
    
    override func remove(done: @escaping DoneHandler) {
        if let publicUrl = asset.publicUrl {
            foregroundSession.delete(publicUrl, credential: credential) { error in
                if error == nil {
                    self.asset.setUploaded(nil)
                }
                
                self.foregroundSession.delete(publicUrl.appendingPathExtension(Asset.Files.meta.rawValue), credential: self.credential) { error in
                    
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
     - parameter timeout: Maximum time to wait for mkdir (default 10 seconds).
     - returns: An error or `nil` on success.
     */
    private func create(folder: URL, _ progress: Progress, label: String = "folder", timeout: TimeInterval = 10.0) -> Error? {
        Self.knownFoldersLock.lock()
        let alreadyKnown = Self.knownFolders.contains(folder)
        Self.knownFoldersLock.unlock()

        if alreadyKnown {
            #if DEBUG
            print("[WebDavConduit] mkdir skip cached label=\(label)")
            #endif
            return nil
        }

        let inBackground = WebDavUploadManager.shared.isEffectivelyBackgrounded
        if inBackground {
            #if DEBUG
            print("[WebDavConduit] mkdir skip background label=\(label) path=\(folder.lastPathComponent)")
            #endif
            Self.knownFoldersLock.lock()
            Self.knownFolders.insert(folder)
            Self.knownFoldersLock.unlock()
            return nil
        }

        #if DEBUG
        print("[WebDavConduit] mkdir start label=\(label) path=\(folder.lastPathComponent)")
        #endif

        var error: Error? = nil
        let start = Date()

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

        progress.addChild(task.progress, withPendingUnitCount: 1)

        // Wait with timeout to prevent blocking forever
        let result = group.wait(timeout: timeout, signal: progress)

        if result == .timedOut {
            #if DEBUG
            print("[WebDavConduit] mkdir timeout (during upload) label=\(label) — will retry upload")
            #endif
            // Return timeout error so upload retries with fresh folder prep attempt.
            // Don't mark as known - next attempt should try mkdir again.
            return NSError(
                domain: NSURLErrorDomain,
                code: URLError.timedOut.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Folder creation timed out"]
            )
        }

        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 2.0 {
            #if DEBUG
            print("[WebDavConduit] mkdir slow (\(String(format: "%.1f", elapsed))s) label=\(label)")
            #endif
        }

        if error == nil {
            Self.knownFoldersLock.lock()
            Self.knownFolders.insert(folder)
            Self.knownFoldersLock.unlock()
            #if DEBUG
            print("[WebDavConduit] mkdir ok label=\(label)")
            #endif
        } else {
            #if DEBUG
            print("[WebDavConduit] mkdir failed label=\(label) error=\(String(describing: error))")
            #endif
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
        
        foregroundSession.info(path, credential: credential) { info, error in
            exists = info.first != nil && info.first!.size == expectedSize
            group.leave()
        }
        
        group.wait()
        
        return exists
    }
    
    /**
     Writes an `Asset`'s metadata to a destination on the WebDAV server.
     Runs **before** the main media PUT (meta is required). When backgrounded,
     uses the background session + file upload so meta survives FG↔BG / kill.
     
     - parameter folder: The destination folder on the WebDAV server.
     - returns: An eventual error.
     */
    private func copyMetadata(to folder: URL, _ progress: Progress,hasPhAsset:Bool=true) -> Error? {
        let metaDest = construct(url: folder, asset.filename)
            .appendingPathExtension(Asset.Files.meta.rawValue)

        do {
            let json = try Conduit.jsonEncoder.encode(asset)

            if WebDavUploadManager.shared.isEffectivelyBackgrounded {
                // BG session cannot use Data payloads — write a temp file and PUT from disk.
                // Use Documents/Metadata (not /tmp) so file survives iOS cleanup while suspended.
                let metaDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Metadata", isDirectory: true)
                try? FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)

                let temp = metaDir.appendingPathComponent(UUID().uuidString + "_" + asset.filename + ".meta.json")
                try json.write(to: temp, options: .atomic)
                let task = backgroundSession.upload(
                    temp,
                    to: metaDest,
                    headers: nil,
                    credential: credential
                )
                task.taskDescription = "webdav-meta:\(temp.path)"
#if DEBUG
                print("[WebDavConduit] meta.json enqueued on BG session before main file=\(asset.filename)")
#endif
            } else {
                _ = foregroundSession.upload(
                    json, to: metaDest, headers: nil, credential: credential
                ) { error in
                    if let error = error {
                        #if DEBUG
                        print("meta.json upload failed: \(error.localizedDescription)")
                        #endif
                    } else {
                        #if DEBUG
                        print("meta.json uploaded successfully.")
                        #endif
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Failed to encode meta.json: \(error.localizedDescription)")
            #endif
        }
        
        // Proof files still need an active FG session; skip while suspended
        // (meta above is the critical sidecar for transitions).
        if !hasPhAsset, !WebDavUploadManager.shared.isEffectivelyBackgrounded {
            uploadProofMode(to: folder) { source, destination in
                guard source.exists else {
                    #if DEBUG
                    print("Missing proof file: \(source.lastPathComponent)")
                    #endif
                    return true
                }
                
                _ = foregroundSession.upload(
                    source, to: destination, headers: nil, credential: credential
                ) { error in
                    if let error = error {
                        #if DEBUG
                        print("Failed to upload proof file \(source.lastPathComponent): \(error.localizedDescription)")
                        #endif
                    } else {
                        #if DEBUG
                        print("Uploaded proof file: \(destination.lastPathComponent)")
                        #endif
                    }
                }
                
                return true
            }
        }
        
        return nil // Don't block upload flow
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
                let readOffset = offset

                var dest = folder
                dest.append(String(format: "%015d-%015d", readOffset, readOffset + expectedSize - 1))

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
                        chunk = try Conduit.readChunk(file, offset: UInt64(readOffset), length: expectedSize)
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
