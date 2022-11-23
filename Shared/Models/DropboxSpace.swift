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

    // Dropbox doesn't support parallel access to different accounts,
    // so there's only ever going to be one DropboxSpace, which this
    // getter will find, if it exists.
    class var space: DropboxSpace? {
        var dropboxSpace: DropboxSpace?

        Db.bgRwConn?.read { transaction in
            transaction.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
                if let space = space as? DropboxSpace {
                    dropboxSpace = space
                    stop = true
                }
            }
        }

        return dropboxSpace
    }

    var email: String?


    init(uid: String? = nil, accessToken: String? = nil) {
        super.init(name: DropboxSpace.defaultPrettyName, url: nil,
                   username: uid, password: accessToken)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        email = decoder.decodeObject(of: NSString.self, forKey: "email") as? String
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
        coder.encode(email, forKey: "email")
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
