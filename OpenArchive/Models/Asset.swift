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

    init(created: Date?) {
        self.created = created ?? Date()
    }

    convenience override init() {
        self.init(created: nil)
    }

    // MARK: NSCoding

    convenience required init(coder aDecoder: NSCoder) {
        self.init(created: aDecoder.decodeObject() as? Date)
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(created)
    }

    // MARK: Methods

    func getKey() -> String {
        return created.description
    }

}
