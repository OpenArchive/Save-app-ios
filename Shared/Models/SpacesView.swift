//
//  SpacesView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class SpacesView: YapDatabaseAutoView {

    static let name = Space.collection

    static let groups = [Space.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            return Space.collection == collection ? collection : nil
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            return (object1 as! Space).compare(object2 as! Space)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
