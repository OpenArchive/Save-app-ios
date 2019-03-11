//
//  AssetsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
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

            return Asset.collection == collection ? collection : nil
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            if let lhs = object1 as? Asset,
                let rhs = object2 as? Asset {

                if lhs.isUploaded != rhs.isUploaded {
                    return lhs.isUploaded
                        ? .orderedDescending
                        : .orderedAscending
                }

                let lhscoll = lhs.collection
                let rhscoll = rhs.collection

                return (lhscoll.uploaded ?? lhscoll.closed ?? lhs.created)
                    .compare(rhscoll.uploaded ?? rhscoll.closed ?? rhs.created)
            }

            return .orderedSame
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
