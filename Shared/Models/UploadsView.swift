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

        let sorting = YapDatabaseViewSorting.withObjectBlock { transaction, group, collection1, key1, object1, collection2, key2, object2 in
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
