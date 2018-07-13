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

    static var accessKey: String? {
        get {
            return UserDefaults.standard.string(forKey: InternetArchive.ACCESS_KEY)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: InternetArchive.ACCESS_KEY)
        }
    }

    static var secretKey: String? {
        get {
            return UserDefaults.standard.string(forKey: InternetArchive.SECRET_KEY)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: InternetArchive.SECRET_KEY)
        }
    }

    // MARK: Methods

    override func getPrettyName() -> String {
        return InternetArchive.PRETTY_NAME
    }

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {

        if type(of: asset) != Image.self {
            publicUrl = nil
            isUploaded = false
            error = "The Internet Archive adapter currently only supports images!"
        }

        let image = asset as! Image

        if publicUrl == nil {
//            let slug = (StringUtils.slug(image.title != nil ? image.title!
//                : String(image.filename.split(separator: ".")[0]))) + "-" + StringUtils.random(4)

            let slug = "IMG-0003-u4z6"

            publicUrl = URL(string: "\(InternetArchive.BASE_URL)/\(slug)/\(image.filename)")
        }


        if let accessKey = InternetArchive.accessKey,
            let secretKey = InternetArchive.secretKey,
            let url = publicUrl {

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

            image.fetchData() { data, uti, orientation, info in
                if let data = data {
                    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory() + UUID().uuidString)

                    if (try? data.write(to: tempFile)) != nil {
                        Server.sessionManager.upload(tempFile, to: url, method: .put, headers: headers)
                            .uploadProgress() { prog in
                                progress(self, prog)
                            }
                            .validate(statusCode: 200..<300)
                            .responseData() { response in
                                try? FileManager.default.removeItem(at: tempFile)

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
            }
        }
    }
}
