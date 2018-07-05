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
    var title: String?
    var desc: String?
    var author: String?
    var location: String?
    var tags: [String]?
    var license: String?

    init(created: Date?) {
        self.created = created ?? Date()
    }

    convenience override init() {
        self.init(created: nil)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        created = decoder.decodeObject() as? Date ?? Date()
        title = decoder.decodeObject() as? String
        desc = decoder.decodeObject() as? String
        author = decoder.decodeObject() as? String
        location = decoder.decodeObject() as? String
        tags = decoder.decodeObject() as? [String]
        license = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(created)
        coder.encode(title)
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
