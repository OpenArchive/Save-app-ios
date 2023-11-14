//
//  AbcFilteredByCollectionView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A child view of `AssetsByCollectionView` which can filter that by collection.

 Use `updateFilter(:)` to engage filtering.
 */
@objc(AbcFilteredByCollectionView)
class AbcFilteredByCollectionView: YapDatabaseFilteredView {

    static let name = "assets_by_collection_filtered_by_collection"

    /**
     A mapping which reverse sorts the groups by creation date of the collection
     they represent, due to the specific construction of the group key.

      See `AssetsByCollectionView#groupKey(for:)` for reference.
    */
    class func createMappings() -> YapDatabaseViewMappings {
        return YapDatabaseViewMappings(
            groupFilterBlock: { group, transaction in
                return true
        },
            sortBlock: { group1, group2, transaction in
                return group2.compare(group1)
        },
            view: name)
    }

    override init() {

        // No need to persist this, it changes way to often.
        let options = YapDatabaseViewOptions()
        options.isPersistent = false

        super.init(parentViewName: AssetsByCollectionView.name,
                   filtering: AbcFilteredByCollectionView.getFilter(),
                   versionTag: nil, options: options)
    }

    /**
     Update filter to a new `collectionId`.

     - parameter collectionId: The collection ID to filter by.
        `nil` will disable the filter and show all entries.
    */
    class func updateFilter(_ collectionId: String? = nil) {
        // Note: This needs to be synchronous. Otherwise, we will have a lot of
        // race conditions in the UI.
        Db.writeConn?.readWrite { tx in
            (tx.ext(name) as? YapDatabaseFilteredViewTransaction)?
                .setFiltering(getFilter(collectionId), versionTag: UUID().uuidString)
        }
    }

    /**
     - parameter collectionId: The collection ID to filter by.
     `nil` will disable the filter and show no entries.
     - returns: a filter block using the given collectionId as criteria.
     */
    private class func getFilter(_ collectionId: String? = nil) -> YapDatabaseViewFiltering {
        if collectionId == nil {
            return YapDatabaseViewFiltering.withKeyBlock { _, _, _, _ in
                return false
            }
        }

        return YapDatabaseViewFiltering.withKeyBlock { _, group, _, _ in
            return AssetsByCollectionView.collectionId(from: group) == collectionId
        }
    }
}
