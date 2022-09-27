//
//  IaSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special space supporting the Internet Archive.
 */
class IaSpace: Space, Item {

    static let baseUrl = "https://s3.us.archive.org"


    // MARK: Item

    override class func fixArchiverName() {
        NSKeyedArchiver.setClassName("IaSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "IaSpace")
    }

    func compare(_ rhs: IaSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: IaSpace

    static let favIcon = UIImage(named: "InternetArchiveLogo")


    init(accessKey: String? = nil, secretKey: String? = nil) {
        super.init(name: IaSpace.defaultPrettyName, url: URL(string: IaSpace.baseUrl),
                   username: accessKey, password: secretKey)
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


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true


    // MARK: NSCopying

    @objc(copyWithZone:) func copy(with zone: NSZone? = nil) -> Any {
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
    }
}
