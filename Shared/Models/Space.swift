//
//  Space.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import FilesProvider

/**
 A `Space` represents the root folder of an upload destination on a WebDAV server.

 It needs to have a `url`, a `username` and a `password`.

 A `name` is optional and is only for a user's informational purposes.
 */
class Space: NSObject, Item {

    // MARK: Item

    static let collection = "spaces"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Space", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Space")
    }

    func compare(_ rhs: Space) -> ComparisonResult {
        return prettyName.compare(rhs.prettyName)
    }

    var id: String


    // MARK: Space
    
    var name: String?
    var url: URL?
    var username: String?
    var password: String?

    var prettyName: String {
        return name ?? url?.host ?? url?.absoluteString ?? WebDavServer.PRETTY_NAME
    }

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `url` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` for this space.
     */
    var provider: WebDAVFileProvider? {
        if let username = username,
            let password = password,
            let baseUrl = url {

            let credential = URLCredential(user: username, password: password, persistence: .forSession)

            let provider = WebDAVFileProvider(baseURL: baseUrl, credential: credential)

            let conf = provider?.session.configuration ?? URLSessionConfiguration.default

            conf.sharedContainerIdentifier = Constants.appGroup
            conf.urlCache = provider?.cache
            conf.requestCachePolicy = .returnCacheDataElseLoad

            // Fix error "CredStore - performQuery - Error copying matching creds."
            conf.urlCredentialStorage = nil

            provider?.session = URLSession(configuration: conf,
                                           delegate: provider?.session.delegate,
                                           delegateQueue: provider?.session.delegateQueue)

            return provider
        }

        return nil
    }

    init(_ name: String? = nil, _ url: URL? = nil, _ username: String? = nil, _ password: String? = nil) {
        id = UUID().uuidString
        self.name = name
        self.url = url
        self.username = username
        self.password = password
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        name = decoder.decodeObject() as? String
        url = decoder.decodeObject() as? URL
        username = decoder.decodeObject() as? String
        password = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
        coder.encode(url)
        coder.encode(username)
        coder.encode(password)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), url=\(url?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password ?? "nil")]"
    }
}
