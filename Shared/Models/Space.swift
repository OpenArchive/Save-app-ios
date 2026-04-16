//
//  Space.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A `Space` represents the root folder of an upload destination on a WebDAV server.

 It needs to have a `url`, a `username` and a `password`.

 A `name` is optional and is only for a user's informational purposes.
 */
class Space: NSObject {

    /**
      Needed for screenshot testing.
     */
    class func fixArchiverName() {
        NSKeyedArchiver.setClassName("Space", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Space")
    }


    func preheat(_ tx: YapDatabaseReadTransaction, deep: Bool = true) {
        // Ignored. Nothing to do.
    }

    /**
     Maximum number of failed uploads per space before the circuit breaker opens.
     */
    static let maxFails = 10

    // MARK: Item - implemented by sublcasses

    static var collection: String {
        return "spaces"
    }

    func compare(_ rhs: Space) -> ComparisonResult {
        return prettyName.compare(rhs.prettyName)
    }

    var id: String


    // MARK: Space

    class var defaultPrettyName: String {
        return NSLocalizedString("Private Server", comment: "")
    }

    var name: String?
    var url: URL?
    var favIcon: UIImage?
    var username: String?

    /// Password is persisted in the iOS Keychain, not in the database.
    var password: String? {
        get { KeychainHelper.retrieveString(key: keychainPasswordKey) }
        set {
            if let value = newValue {
                KeychainHelper.save(key: keychainPasswordKey, string: value)
            } else {
                KeychainHelper.delete(key: keychainPasswordKey)
            }
        }
    }

    /// Stable Keychain key scoped to this space.
    var keychainPasswordKey: String { "space.\(id).password" }

    var isNextcloud = false
    var authorName: String?
    var authorRole: String?
    var authorOther: String?
    var license: String?

    // Circuit breaker pattern for uploads
    var tries = 0
    var lastTry: Date?
    var nextTry: Date {
        lastTry?.addingTimeInterval(10 * 60) ?? Date(timeIntervalSince1970: 0)
    }
    var uploadAllowed: Bool {
        tries < Space.maxFails || nextTry.compare(Date()) == .orderedAscending
    }

    var prettyName: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        if let host = url?.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }

        if let url = url?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }

        return Space.defaultPrettyName
    }

    init(name: String? = nil, url: URL? = nil, favIcon: UIImage? = nil,
         username: String? = nil, password: String? = nil,
         authorName: String? = nil, authorRole: String? = nil,
         authorOther: String? = nil, license: String? = nil
    ) {

        id = UUID().uuidString
        self.name = name
        self.url = url
        self.favIcon = favIcon
        self.username = username
        self.authorName = authorName
        self.authorRole = authorRole
        self.authorOther = authorOther
        self.license = license
        super.init()
        // password is a computed property backed by Keychain; must be set after super.init()
        self.password = password
    }


    // MARK: NSSecureCoding

    @objc(initWithCoder:)
    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject(of: NSString.self, forKey: "id") as? String ?? UUID().uuidString
        name = decoder.decodeObject(of: NSString.self, forKey: "name") as? String
        url = decoder.decodeObject(of: NSURL.self, forKey: "url") as? URL
        favIcon = decoder.decodeObject(of: UIImage.self, forKey: "favIcon")
        username = decoder.decodeObject(of: NSString.self, forKey: "username") as? String
        isNextcloud = decoder.decodeBool(forKey: "nextcloud")

        // Migration: if password was previously stored in DB, move it to Keychain and clear it.
        if let legacyPassword = decoder.decodeObject(of: NSString.self, forKey: "password") as? String,
           !legacyPassword.isEmpty,
           KeychainHelper.retrieveString(key: "space.\(id).password") == nil {
            KeychainHelper.save(key: "space.\(id).password", string: legacyPassword)
        }
        authorName = decoder.decodeObject(of: NSString.self, forKey: "authorName") as? String
        authorRole = decoder.decodeObject(of: NSString.self, forKey: "authorRole") as? String
        authorOther = decoder.decodeObject(of: NSString.self, forKey: "authorOther") as? String
        license = decoder.decodeObject(of: NSString.self, forKey: "license") as? String
        tries = decoder.decodeInteger(forKey: "tries")
        lastTry = decoder.decodeObject(of: NSDate.self, forKey: "lastTry") as? Date
    }

    @objc(encodeWithCoder:) func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(url, forKey: "url")
        coder.encode(favIcon, forKey: "favIcon")
        coder.encode(username, forKey: "username")
        // password is stored in Keychain, not the database
        coder.encode(isNextcloud, forKey: "nextcloud")
        coder.encode(authorName, forKey: "authorName")
        coder.encode(authorRole, forKey: "authorRole")
        coder.encode(authorOther, forKey: "authorOther")
        coder.encode(license, forKey: "license")
        coder.encode(tries, forKey: "tries")
        coder.encode(lastTry, forKey: "lastTry")
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), url=\(url?.description ?? "nil"), "
            + "favIcon=\(favIcon?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password != nil ? "[redacted]" : "nil"), "
            + "isNextcloud=\(isNextcloud), "
            + "authorName=\(authorName ?? "nil"), authorRole=\(authorRole ?? "nil"), "
            + "authorOther=\(authorOther ?? "nil"), license=\(license ?? "nil"), "
            + "tries=\(tries), lastTry=\(String(describing: lastTry))]"
    }
}
