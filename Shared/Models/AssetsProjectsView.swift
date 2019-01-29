//
//  AssetsProjectsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class AssetsProjectsView: YapDatabaseAutoView {

    static let name = "assets_projects"

    static let groups = [Asset.collection, Project.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            switch collection {
            case Asset.collection, Project.collection:
                return collection

            default:
                return nil
            }
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            if Asset.collection == group {
                return (object1 as! Asset).compare(object2 as! Asset)
            }

            return (object1 as! Project).compare(object2 as! Project)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
