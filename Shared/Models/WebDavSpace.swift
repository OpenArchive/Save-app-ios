//
//  WebDavSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A space supporting WebDAV servers such as Nextcloud/Owncloud.
 */
class WebDavSpace: Space, Item {

    // MARK: Item

    override class func fixArchiverName() {
        NSKeyedArchiver.setClassName("WebDavSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "WebDavSpace")
    }

    func compare(_ rhs: WebDavSpace) -> ComparisonResult {
        return super.compare(rhs)
    }

    var credential: URLCredential? {
        if let username = username,
           let password = password
        {
            return URLCredential(user: username, password: password, persistence: .forSession)
        }

        return nil
    }

    /**
     Creates an ephemeral foreground session without caching and which already contains BASIC auth credentials.

     Don't use this for uploads. This is only useful for foreground UI interaction!
     */
    var session: URLSession {
        if _session == nil {
            let conf = URLSessionConfiguration.ephemeral
            conf.urlCache = nil
            conf.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            if let basicAuth = credential?.basicAuth {
                conf.httpAdditionalHeaders = ["Authorization": basicAuth]
            }

            _session = URLSession.withImprovedConf(configuration: conf)
        }

        return _session!
    }
    private var _session: URLSession?


    override init(name: String? = nil, url: URL? = nil, favIcon: UIImage? = nil,
                  username: String? = nil, password: String? = nil,
                  authorName: String? = nil, authorRole: String? = nil,
                  authorOther: String? = nil) {

        super.init(name: name, url: url, favIcon: favIcon, username: username,
                   password: password, authorName: authorName,
                   authorRole: authorRole, authorOther: authorOther)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true


    // MARK: NSCopying

    @objc(copyWithZone:) func copy(with zone: NSZone? = nil) -> Any {
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
    }
}
