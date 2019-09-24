//
//  WebDavSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

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
            let password = password {

            return URLCredential(user: username, password: password, persistence: .forSession)
        }

        return nil
    }

    /**
     Create a `WebDAVFileProvider`.

     - parameter baseURL: The base URL of the WebDAV server.
     - parameter credential: The credential to authenticate with.
     - returns: a `WebDAVFileProvider` for this space.
     */
    static func createProvider(baseUrl: URL, credential: URLCredential) -> WebDAVFileProvider? {
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

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `url` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` for this space.
     */
    var provider: WebDAVFileProvider? {
        if let baseUrl = url, let credential = credential {
            return WebDavSpace.createProvider(baseUrl: baseUrl, credential: credential)
        }

        return nil
    }


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
}
