//
//  AssetsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class AssetsView: YapDatabaseAutoView {

    static let name = Asset.collection

    static let groups = [Asset.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            switch collection {
            case Asset.collection:
                return collection

            default:
                return nil
            }
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            return (object1 as! Asset).compare(object2 as! Asset)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
