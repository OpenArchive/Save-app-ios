//
//  AssetsByCollectionView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class AssetsByCollectionView: YapDatabaseAutoView {

    static let name = "assets_by_collection"

    override init() {
        let grouping = YapDatabaseViewGrouping.withObjectBlock() {
            transaction, collection, key, object in

            return AssetsByCollectionView.groupKey(for: object as? Asset)
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            return (object1 as! Asset).compare(object2 as! Asset)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }

    class func groupKey(for asset: Asset?) -> String? {
        if let asset = asset {
            return "\(asset.collection.projectId)/\(asset.collectionId)"
        }

        return nil
    }

    class func projectId(from group: String?) -> String? {
        if let group = group {
            return String(group.split(separator: "/")[0])
        }

        return nil
    }

    class func collectionId(from group: String?) -> String? {
        if let group = group {
            return String(group.split(separator: "/")[1])
        }

        return nil
    }
}
