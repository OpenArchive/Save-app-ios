//
//  DropboxSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.02.20.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special space supporting Dropbox.
 */
class DropboxSpace: Space, Item {

    static let baseUrl = "https://s3.us.archive.org"


    // MARK: Item

    override class func fixArchiverName() {
        NSKeyedArchiver.setClassName("DropboxSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "DropboxSpace")
    }

    func compare(_ rhs: DropboxSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: DropboxSpace

    static let favIcon = UIImage(named: "dropbox-icon")


    init(accessKey: String? = nil, secretKey: String? = nil) {
        super.init(name: DropboxSpace.defaultPrettyName, url: URL(string: DropboxSpace.baseUrl),
                   username: accessKey, password: secretKey)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: Space

    override class var defaultPrettyName: String {
        return "Dropbox"
    }

    override var favIcon: UIImage? {
        get {
            return DropboxSpace.favIcon
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
}
