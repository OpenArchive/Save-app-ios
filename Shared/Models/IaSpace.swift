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

    private static let BASE_URL = "https://s3.us.archive.org"

    static let favIcon = UIImage(named: "InternetArchiveLogo")

    /**
     This needs to be tied to this object, otherwise the SessionManager will get
     destroyed during the request and the request will break with error -999.

     See [Getting code=-999 using custom SessionManager](https://github.com/Alamofire/Alamofire/issues/1684)
     */
    private lazy var sessionManager: SessionManager = {
        let conf = Space.sessionConf
        conf.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: conf)
    }()


    init(accessKey: String? = nil, _ secretKey: String? = nil) {
        super.init(IaSpace.defaultPrettyName, URL(string: IaSpace.BASE_URL), nil, accessKey, secretKey)
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
        coder.encode(id)
        coder.encode(name)
        coder.encode(url)
        coder.encode(nil)
        coder.encode(username)
        coder.encode(password)
    }


    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {

        if asset.publicUrl == nil {
            var slug = StringUtils.slug(asset.title != nil
                ? asset.title!
                : StringUtils.stripSuffix(from: asset.filename))

            slug = slug + "-" + StringUtils.random(4)

//            slug = "IMG-0003-u4z6"

            asset.publicUrl = URL(string: "\(IaSpace.BASE_URL)/\(slug)/\(asset.filename)")
        }

        if let accessKey = username,
            let secretKey = password,
            let url = asset.publicUrl {

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

            upload(asset, to: url, headers: headers, progress: progress, done: done)
        }
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
                        asset.error = nil
                    case .failure(let error):
                        asset.error = error.localizedDescription
                    }

                    done(asset)
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                asset.error = nil

                done(asset)
            }
        }
    }


    // MARK: Private Methods

    /**
     Upload a given asset to a server using a background session.

     We need to do this with a file: "Upload tasks from NSData are not supported in background sessions."

     - parameter asset: The asset to upload.
     - parameter url: The URL to upload to.
     - parameter headers: The HTTP headers to use.
     - parameter progress: The progress callback.
     - parameter done: The done callback, which is called always when finished.
     */
    private func upload(_ asset: Asset, to url: URLConvertible, headers: HTTPHeaders,
                        progress: @escaping ProgressHandler, done: @escaping DoneHandler) {

        if let file = asset.file {
            sessionManager.upload(file, to: url, method: .put, headers: headers)
                .debug()
                .uploadProgress() { prog in
                    progress(asset, prog)
                }
                .validate(statusCode: 200..<300)
                .responseData() { response in
                    switch response.result {
                    case .success:
                        asset.isUploaded = true
                        asset.error = nil
                    case .failure(let error):
                        asset.publicUrl = nil
                        asset.isUploaded = false
                        asset.error = error.localizedDescription
                    }

                    done(asset)
            }
        }
    }
}
