//
//  IaSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Alamofire

/**
 A special space supporting the Internet Archive.
 */
class IaSpace: Space, Item {

    // MARK: Item

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("IaSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "IaSpace")
    }

    func compare(_ rhs: IaSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: IaSpace

    private static let baseUrl = "https://s3.us.archive.org"

    static let favIcon = UIImage(named: "InternetArchiveLogo")


    init(accessKey: String? = nil, secretKey: String? = nil) {
        super.init(name: IaSpace.defaultPrettyName, url: URL(string: IaSpace.baseUrl), username: accessKey, password: secretKey)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: Space

    override class var defaultPrettyName: String {
        return "Internet Archive"
    }

    override var favIcon: UIImage? {
        get {
            return IaSpace.favIcon
        }
        set {
            // This is effectively read-only.
        }
    }

    /**
     Don't store the favIcon in the database. It's bundled with the app anyway.
     */
    @objc(encodeWithCoder:) override func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(url, forKey: "url")
        coder.encode(nil, forKey: "favIcon")
        coder.encode(username, forKey: "username")
        coder.encode(password, forKey: "password")
        coder.encode(authorName, forKey: "authorName")
        coder.encode(authorRole, forKey: "authorRole")
        coder.encode(authorOther, forKey: "authorOther")
        coder.encode(tries, forKey: "tries")
        coder.encode(lastTry, forKey: "lastTry")
    }

    override func upload(_ asset: Asset, uploadId: String) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        guard let accessKey = username,
            let secretKey = password,
            let file = asset.file,
            let url = url(for: asset)
            else {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                    self.done(uploadId, InvalidConfError())
                }

                return progress
        }

        var headers: HTTPHeaders = [
            "Accept": "*/*",
            "authorization": "LOW \(accessKey):\(secretKey)",
            "x-amz-auto-make-bucket": "1",
            "x-archive-auto-make-bucket": "1",
            "x-archive-interactive-priority": "1",
            "x-archive-meta-mediatype": asset.mimeType,
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

        if let tags = asset.tags, tags.count > 0 {
            headers["x-archive-meta-subject"] = tags.joined(separator: ";")
        }

        if let license = asset.license, !license.isEmpty {
            headers["x-archive-meta-licenseurl"] = license
        }

        self.upload(file, to: url, progress, headers: headers) { error in
            self.done(uploadId, error, url)
        }

        return progress
    }

    override func remove(_ asset: Asset, done: @escaping DoneHandler) {
        if let accessKey = username,
            let secretKey = password,
            let url = asset.publicUrl {

            let headers: HTTPHeaders = [
                "Accept": "*/*",
                "authorization": "LOW \(accessKey):\(secretKey)",
                "x-archive-cascade-delete": "1",
                "x-archive-keep-old-version": "0",
                ]

            sessionManager.request(url, method: .delete, headers: headers)
                .debug()
                .validate(statusCode: 200..<300)
                .responseData() { response in

                    switch response.result {
                    case .success:
                        asset.publicUrl = nil
                        asset.isUploaded = false
                    default:
                        break
                    }

                    done(asset)
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                done(asset)
            }
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

        return URL(string: "\(IaSpace.baseUrl)/\(slug)/\(asset.filename)")
    }
}
