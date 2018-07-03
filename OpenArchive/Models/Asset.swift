//
//  Asset.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class Asset: NSObject, NSCoding {

    static let COLLECTION = "assets"

    let created: Date
    let desc: String?
    let author: String?
    let location: String?
    let tags: [String]?
    let license: String?

    init(created: Date?, desc: String?, author: String?, location: String?, tags: [String]?, license: String?) {
        self.created = created ?? Date()
        self.desc = desc
        self.author = author
        self.location = location
        self.tags = tags
        self.license = license
    }

    convenience override init() {
        self.init(created: nil, desc: nil, author: nil, location: nil, tags: nil, license: nil)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        self.created = decoder.decodeObject() as? Date ?? Date()
        self.desc = decoder.decodeObject() as? String
        self.author = decoder.decodeObject() as? String
        self.location = decoder.decodeObject() as? String
        self.tags = decoder.decodeObject() as? [String]
        self.license = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(created)
        coder.encode(desc)
        coder.encode(author)
        coder.encode(location)
        coder.encode(tags)
        coder.encode(license)
    }

    // MARK: Methods

    func getKey() -> String {
        return created.description
    }

}
