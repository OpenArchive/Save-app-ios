//
//  CollectionsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A view which groups all collections by project ID.

 This is needed in order to get noticed on updates to a collection which are
 used for section headers in the `MainViewController`.
 */
class CollectionsView: YapDatabaseAutoView {

    static let name = Collection.collection

    static var mappings: YapDatabaseViewMappings = {
        return YapDatabaseViewMappings(
            groupFilterBlock: { group, transaction in
                return true
        },
            sortBlock: { group1, group2, transaction in
                return group1.compare(group2)
        },
            view: name)
    }()

    override init() {
        let grouping = YapDatabaseViewGrouping.withObjectBlock() {
            transaction, collection, key, object in

            return (object as? Collection)?.projectId
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            // Order by creation date descending. Needs to be the same as the
            // group ordering in `AssetsByCollectionView`.
            return (object2 as! Collection).compare(object1 as! Collection)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
