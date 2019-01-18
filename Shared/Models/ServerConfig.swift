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

    var url: URL?
    var username: String?
    var password: String?

    init(_ url: URL? = nil, _ username: String? = nil, _ password: String? = nil) {
        self.url = url
        self.username = username
        self.password = password
    }

    required init?(coder decoder: NSCoder) {
        url = decoder.decodeObject() as? URL
        username = decoder.decodeObject() as? String
        password = decoder.decodeObject() as? String

    }

    func encode(with coder: NSCoder) {
        coder.encode(url)
        coder.encode(username)
        coder.encode(password)
    }

    override var description: String {
        return "\(String(describing: type(of: self))): [url=\(url?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password ?? "nil")]"
    }
}
