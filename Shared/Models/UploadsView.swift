//
//  AssetsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class UploadsView: YapDatabaseAutoView {

    static let name = Upload.collection

    static let groups = [Upload.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock {
            transaction, collection, key in

            return Upload.collection == collection ? collection : nil
        }

        let sorting = YapDatabaseViewSorting.withKeyBlock {
            transaction, group, collection1, key1, collection2, key2 in

            return key1.compare(key2)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
