//
//  GdriveSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special space supporting Google Drive.
 */
class GdriveSpace: Space, Item {

    // MARK: Item

    override class func fixArchiverName() {
        NSKeyedArchiver.setClassName("GdriveSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "GdriveSpace")
    }

    func compare(_ rhs: GdriveSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: GdriveSpace

    static let favIcon = UIImage(named: "ic_gdrive")?.withRenderingMode(.alwaysTemplate)

    // Google Drive doesn't support parallel access to different accounts,
    // so there's only ever going to be one GdriveSpace, which this
    // getter will find, if it exists.
    class var space: GdriveSpace? {
        Db.bgRwConn?.find(where: { _ in true })
    }

    var email: String?


    init(userId: String? = nil, accessToken: String? = nil) {
        super.init(name: Self.defaultPrettyName, url: nil,
                   username: userId, password: accessToken)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        email = decoder.decodeObject(of: NSString.self, forKey: "email") as? String
    }


    // MARK: Space

    override class var defaultPrettyName: String {
        return "Google Drive"
    }

    override var favIcon: UIImage? {
        get {
            return Self.favIcon
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
        coder.encode(license, forKey: "license")
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
