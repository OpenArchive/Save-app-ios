//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

class IaConduit: Conduit {
    
    // MARK: Conduit
    
    /**
     - Metadata reference: https://github.com/vmbrasseur/IAS3API/blob/master/metadata.md
     */
    override func upload(uploadId: String) -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        guard let accessKey = asset.space?.username,
              let secretKey = asset.space?.password,
              let file = asset.file,
              let url = url(for: asset)
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: UploadError.invalidConf)
            }
            
            return progress
        }
        
        let error = copyMetadataWithoutProofmode(to: url.deletingLastPathComponent(), progress,
                                                 headers: generateHeaders(accessKey, secretKey, forMetadata: true))
        
        if  progress.isCancelled {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: error)
            }
            
            return progress
        }
        
        //Fix to 10% from here, so uploaded bytes can be calculated properly
        // in `UploadCell.upload#didSet`!
        progress.completedUnitCount = 10

        // Validate file exists before attempting upload
        guard FileManager.default.fileExists(atPath: file.path) else {
            let error = NSError(domain: "org.open-archive.save", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "File not found: \(file.path)"])
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: error)
            }
            return progress
        }

        // Copy file to temp directory for background session access
        // Background URLSession cannot reliably access App Group files when app is backgrounded
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + "_" + file.lastPathComponent)

        do {
            // Try hard link first (instant), fall back to copy if it fails
            do {
                try FileManager.default.linkItem(at: file, to: tempFile)
            } catch {
                try FileManager.default.copyItem(at: file, to: tempFile)
            }

            guard FileManager.default.fileExists(atPath: tempFile.path) else {
                throw NSError(domain: "org.open-archive.save", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file"])
            }

            let task = backgroundSession.upload(tempFile, to: url, headers: generateHeaders(accessKey, secretKey), credential: nil)

            // Store temp file path for cleanup
            task.taskDescription = tempFile.path

            progress.addChild(task.progress, withPendingUnitCount: progress.totalUnitCount - progress.completedUnitCount)
        } catch {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: error)
            }
        }

        return progress
    }
    
    override func remove(done: @escaping DoneHandler) {
        if let accessKey = asset.space?.username,
           let secretKey = asset.space?.password,
           let url = asset.publicUrl {
            
            let headers: [String: String] = [
                "Accept": "*/*",
                "authorization": "LOW \(accessKey):\(secretKey)",
                "x-archive-cascade-delete": "1",
                "x-archive-keep-old-version": "0",
            ]
            
            foregroundSession.delete(url, headers: headers) { error in
                if error == nil {
                    self.asset.setUploaded(nil)
                }
                
                done(self.asset)
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                done(asset)
            }
        }
    }
    
    
    // MARK: Private Methods
    
    private func generateHeaders(_ accessKey: String, _ secretKey: String, forMetadata: Bool = false) -> [String: String] {
        var headers: [String: String] = [
            "Accept": "*/*",
            "authorization": "LOW \(accessKey):\(secretKey)",
            "x-amz-auto-make-bucket": "1",
            "x-archive-auto-make-bucket": "1",
        ]
        
#if DEBUG
        headers["x-archive-meta-collection"] = "test_collection"
#else
        headers["x-archive-meta-collection"] = "opensource_media"
#endif
        
        if forMetadata {
            headers["x-archive-queue-derive"] = "0"
        }
        else {
            headers["x-archive-interactive-priority"] = "1"
            headers["x-archive-meta-mediatype"] = mediatype(for: asset)
            
            if let title = asset.title, !title.isEmpty {
                headers["x-archive-meta-title"] = title
            }
            
            if let desc = asset.desc, !desc.isEmpty {
                headers["x-archive-meta-description"] = desc
            }
            
            if let author = asset.author, !author.isEmpty {
                headers["x-archive-meta-author"] = author
            }
            
            if let location = asset.location, !location.isEmpty {
                headers["x-archive-meta-location"] = location
            }
            
            if let notes = asset.notes, !notes.isEmpty {
                headers["x-archive-meta-notes"] = notes
            }
            
            var subject = [String]()
            
            if let projectName = asset.project?.name, !projectName.isEmpty {
                subject.append(projectName)
            }
            
            if let tags = asset.tags, tags.count > 0 {
                subject.append(contentsOf: tags)
            }
            
            if subject.count > 0 {
                headers["x-archive-meta-subject"] = subject.joined(separator: ";")
            }
            
            if let license = asset.license, !license.isEmpty {
                headers["x-archive-meta-licenseurl"] = license
            }
        }
        
        return headers
    }
    
    /**
     Writes an `Asset`'s ProofMode metadata, if any, to a destination on the Internet Archive.
     
     - parameter folder: The destination folder on the Internet Archive.
     - parameter headers: Full Internet Archive headers.
     */
    private func copyMetadata(to folder: URL, _ progress: Progress, headers: [String: String]) -> Error? {
        var error: Error? = nil
        let group = DispatchGroup.enter()
        
        uploadProofMode(to: folder) { source, destination in
            group.enter()
            
            let task = foregroundSession.upload(source, to: destination, headers: headers) { e in
                error = e
                
                group.leave()
            }
            progress.addChild(task.progress, withPendingUnitCount: 1)
            
            group.wait(signal: progress)
            
            return error == nil && !progress.isCancelled
        }
        
        return error
    }
    
    private func copyMetadataWithoutProofmode(to folder: URL, _ progress: Progress, headers: [String: String]) -> Error? {
        // Upload meta.json file - write to temp file so background session can handle it
        do {
            let json = try Conduit.jsonEncoder.encode(asset)

            // Construct URL: {ARCHIVE_API_ENDPOINT}/{identifier}/{filename}.meta.json
            let metaUrl = folder
                .appendingPathComponent(asset.filename + ".meta.json")

            // Write JSON to a temporary file for background session upload
            let tempDir = FileManager.default.temporaryDirectory
            let tempMetaFile = tempDir.appendingPathComponent(UUID().uuidString + ".meta.json")
            try json.write(to: tempMetaFile, options: .atomic)

            let semaphore = DispatchSemaphore(value: 0)
            var uploadError: Error? = nil

            // Use background session for meta.json
            let metaTask = backgroundSession.upload(tempMetaFile, to: metaUrl, headers: headers, credential: nil)

            // Monitor task completion on a background thread to avoid blocking upload queue directly
            DispatchQueue.global(qos: .userInitiated).async {
              
                while metaTask.state != .completed && metaTask.state != .canceling {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempMetaFile)

                if let error = metaTask.error {
                    print("meta.json upload failed: \(error.localizedDescription)")
                    uploadError = error
                } else {
                    print("meta.json uploaded successfully to Internet Archive.")
                }

                semaphore.signal()
            }

            progress.addChild(metaTask.progress, withPendingUnitCount: 1)

            let timeout = DispatchTime.now() + .seconds(60)
            if semaphore.wait(timeout: timeout) == .timedOut {
                print("meta.json upload timed out after 60 seconds")
                return NSError(domain: "org.open-archive.save", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "meta.json upload timed out"])
            }

            return uploadError

        } catch let e {
            print("Failed to encode meta.json: \(e.localizedDescription)")
            return e
        }
    }
    private func url(for asset: Asset) -> URL? {
        if let url = asset.publicUrl {
            return url
        }
        
        var slug = StringUtils.slug(asset.title != nil
                                    ? asset.title!
                                    : StringUtils.stripSuffix(from: asset.filename))
        
        slug = slug + "-" + StringUtils.random(4)
        
        //        slug = "IMG-0003-u4z6"
        
        return construct(url: IaSpace.baseUrl, slug, asset.filename)
    }
    
    private func mediatype(for asset: Asset) -> String {
        if asset.uti.conforms(to: UTType.image) {
            return "image"
        }
        
        if asset.uti.conforms(to: UTType.movie) {
            return "movies"
        }
        
        if asset.uti.conforms(to: UTType.audio) {
            return "audio"
        }
        
        return "data"
    }
}
