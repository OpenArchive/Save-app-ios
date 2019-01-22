//
//  ServerConfig.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ServerConfig: NSObject, NSCoding {

    static let COLLECTION = "serverConfig"

    var name: String?
    var url: URL?
    var username: String?
    var password: String?

    var prettyName: String {
        return name ?? url?.host ?? url?.absoluteString ?? WebDavServer.PRETTY_NAME
    }

    init(_ name: String? = nil, _ url: URL? = nil, _ username: String? = nil, _ password: String? = nil) {
        self.url = url
        self.username = username
        self.password = password
    }

    required init?(coder decoder: NSCoder) {
        name = decoder.decodeObject() as? String
        url = decoder.decodeObject() as? URL
        username = decoder.decodeObject() as? String
        password = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(name)
        coder.encode(url)
        coder.encode(username)
        coder.encode(password)
    }

    override var description: String {
        return "\(String(describing: type(of: self))): [name=\(name ?? "nil"), "
            + "url=\(url?.description ?? "nil"), username=\(username ?? "nil"), "
            + "password=\(password ?? "nil")]"
    }
}
