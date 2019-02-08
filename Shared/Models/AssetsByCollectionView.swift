//
//  AssetsByCollectionView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A view which sections `Asset`s by the `Collection`s they belong to.

 The group key used is sortable by
 `created` date of the `Collection` and filterable by the `projectId` the
 `Collection` belongs to.
 */
class AssetsByCollectionView: YapDatabaseAutoView {

    static let name = "assets_by_collection"

    private static let separator: Character = "/"

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

    /**
     - parameter asset: The `Asset` to generate a group key for.
     - returns: a group key from the asset's collection which is sortable by
        creation date, filterable by project ID and groupable by collection ID.
        Will return `nil` if `Asset` is `nil`.
    */
    class func groupKey(for asset: Asset?) -> String? {
        if let asset = asset {
            let collection = asset.collection
            let created = String(Int(collection.created.timeIntervalSince1970))

            return "\(created)\(separator)\(collection.projectId)\(separator)\(collection.id)"
        }

        return nil
    }

    /**
     - parameter group: A valid group key of this view.
     - returns: the `created` part of the group key as a `Date`.
        Will return `nil` if `group` is `nil` or the group string is invalid.
    */
    class func created(from group: String?) -> Date? {
        if let group = group?.split(separator: separator),
            let epoch = TimeInterval(String(group[0])) {

            return Date(timeIntervalSince1970: epoch)
        }

        return nil
    }

    /**
     - parameter group: A valid group key of this view.
     - returns: the `projectid` part of the group key as a `String`.
        Will return `nil` if `group` is `nil` or the group string is invalid.
    */
    class func projectId(from group: String?) -> String? {
        if let group = group?.split(separator: separator),
            group.count > 1 {

            return String(group[1])
        }

        return nil
    }

    /**
     - parameter group: A valid group key of this view.
     - returns: the `collectionId` part of the group key as a `String`.
        Will return `nil` if `group` is `nil` or the group string is invalid.
     */
    class func collectionId(from group: String?) -> String? {
        if let group = group?.split(separator: separator),
            group.count > 2 {

            return String(group[2])
        }

        return nil
    }
}
