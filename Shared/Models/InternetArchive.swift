//
//  InternetArchive.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Alamofire

class InternetArchive : Server {

    private static let PRETTY_NAME = "Internet Archive"
    private static let ACCESS_KEY = "ACCESS_KEY"
    private static let SECRET_KEY = "SECRET_KEY"

    private static let BASE_URL = "https://s3.us.archive.org"

    /**
     Fix for spurious warning.
     See https://forums.developer.apple.com/thread/51348#discussion-186721
    */
    private static let SUITE_NAME = "\(Constants.teamId).\(Constants.appGroup)"

    static var accessKey: String? {
        get {
            return UserDefaults(suiteName: SUITE_NAME)?.string(forKey: InternetArchive.ACCESS_KEY)
        }
        set {
            UserDefaults(suiteName: SUITE_NAME)?.set(newValue, forKey: InternetArchive.ACCESS_KEY)
        }
    }

    static var secretKey: String? {
        get {
            return UserDefaults(suiteName: SUITE_NAME)?.string(forKey: InternetArchive.SECRET_KEY)
        }
        set {
            UserDefaults(suiteName: SUITE_NAME)?.set(newValue, forKey: InternetArchive.SECRET_KEY)
        }
    }

    private var slug: String?

    required init() {
        super.init()

        // Just here to satisfy init using a dynamic type variable.
    }

    // MARK: Methods

    override func getPrettyName() -> String {
        return InternetArchive.PRETTY_NAME
    }

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {

        if publicUrl == nil {
            if slug == nil {
                slug = StringUtils.slug(asset.title != nil
                    ? asset.title!
                    : StringUtils.stripSuffix(from: asset.filename))

                slug = slug! + "-" + StringUtils.random(4)

//                slug = "IMG-0003-u4z6"
            }

            publicUrl = URL(string: "\(InternetArchive.BASE_URL)/\(slug!)/\(asset.filename)")
        }

        if let accessKey = InternetArchive.accessKey,
            let secretKey = InternetArchive.secretKey,
            let url = publicUrl,
            let file = asset.file {

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

            upload(file, to: url, headers: headers, progress: progress, done: done)
        }
    }

    override func remove(_ asset: Asset, done: @escaping DoneHandler) {
        if let accessKey = InternetArchive.accessKey,
            let secretKey = InternetArchive.secretKey,
            let url = publicUrl {

            let headers: HTTPHeaders = [
                "Accept": "*/*",
                "authorization": "LOW \(accessKey):\(secretKey)",
                "x-archive-cascade-delete": "1",
                "x-archive-keep-old-version": "0",
            ]

            Server.sessionManager.request(url, method: .delete, headers: headers)
                .debug()
                .validate(statusCode: 200..<300)
                .responseData() { response in

                    switch response.result {
                    case .success:
                        self.publicUrl = nil
                        self.isUploaded = false
                        self.error = nil
                    case .failure(let error):
                        self.error = error.localizedDescription
                    }

                    done(self)
                }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                self.error = nil

                done(self)
            }
        }
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)

        slug = decoder.decodeObject() as? String
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)

        coder.encode(slug)
    }

    // MARK: Private Methods

    /**
     Upload a given file to a server using a background session.

     We need to do this with a file: "Upload tasks from NSData are not supported in background sessions."

     - parameter file: The file to upload.
     - parameter url: The URL to upload to.
     - parameter headers: The HTTP headers to use.
     - parameter progress: The progress callback.
     - parameter done: The done callback, which is called always when finished.
    */
    private func upload(_ file: URL, to url: URLConvertible, headers: HTTPHeaders,
                        progress: @escaping ProgressHandler, done: @escaping DoneHandler) {

        Server.sessionManager.upload(file, to: url, method: .put, headers: headers)
            .debug()
            .uploadProgress() { prog in
                progress(self, prog)
            }
            .validate(statusCode: 200..<300)
            .responseData() { response in
                switch response.result {
                case .success:
                    self.isUploaded = true
                    self.error = nil
                case .failure(let error):
                    self.publicUrl = nil
                    self.isUploaded = false
                    self.error = error.localizedDescription
                }

                done(self)
        }

    }
}
