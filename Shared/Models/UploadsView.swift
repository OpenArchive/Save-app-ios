//
//  AssetsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 Tracks changes in all `Upload` (first section) and `Asset` (second section) objects.
 */
class UploadsView: YapDatabaseAutoView {

    static let name = Upload.collection

    static let groups = [Upload.collection, Asset.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock {
            transaction, collection, key in

            switch collection {
            case Upload.collection, Asset.collection:
                    return collection

            default:
                return nil
            }
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock { transaction, group, collection1, key1, object1, collection2, key2, object2 in
            if Asset.collection == collection1,
                let asset1 = object1 as? Asset,
                let asset2 = object2 as? Asset {
                return asset1.compare(asset2)
            }

            let upload1 = object1 as? Upload
            let upload2 = object2 as? Upload

            if upload1 == nil {
                if upload2 != nil {
                    return .orderedDescending
                }

                return .orderedSame
            }
            else {
                if upload2 == nil {
                    return .orderedAscending
                }
            }

            return upload1!.compare(upload2!)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
