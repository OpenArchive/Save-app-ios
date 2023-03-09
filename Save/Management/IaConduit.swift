//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import LegacyUTType

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

        var headers: [String: String] = [
            "Accept": "*/*",
            "authorization": "LOW \(accessKey):\(secretKey)",
            "x-amz-auto-make-bucket": "1",
            "x-archive-auto-make-bucket": "1",
            "x-archive-interactive-priority": "1",
            "x-archive-meta-mediatype": mediatype(for: asset),
            "x-archive-meta-collection": "opensource_media",
        ]

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

        copyMetadata(to: url, progress, headers: headers)

        //Fix to 10% from here, so uploaded bytes can be calculated properly
        // in `UploadCell.upload#didSet`!
        progress.completedUnitCount = 10

        // No callback, handling of the finished upload will be done in
        // ``UploadManager.urlSession(:task:didCompleteWithError:)``.
        upload(file, to: url, progress, headers: headers)

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

    /**
     Writes an `Asset`'s ProofMode metadata, if any, to a destination on the Internet Archive.

     - parameter to: The destination on the Internet Archive.
     - parameter headers: Full Internet Archive headers.
     */
    private func copyMetadata(to: URL, _ progress: Progress, headers: [String: String]) {
        uploadProofMode { file, ext in
            upload(file, to: to.appendingPathExtension(ext), progress, pendingUnitCount: 1, headers: headers)

            return !progress.isCancelled
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
        if asset.uti.conforms(to: .image) {
            return "image"
        }

        if asset.uti.conforms(to: .movie) {
            return "movies"
        }

        if asset.uti.conforms(to: .audio) {
            return "audio"
        }

        return "data"
    }
}
