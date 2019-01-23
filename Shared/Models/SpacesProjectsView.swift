//
//  SpacesProjectsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class SpacesProjectsView: YapDatabaseAutoView {

    static let name = "spaces_projects"

    static let groups = [Space.collection, Project.collection]

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            switch collection {
            case Space.collection, Project.collection:
                return collection

            default:
                return nil
            }
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            if Space.collection == group {
                return (object1 as! Space).compare(object2 as! Space)
            }

            return (object1 as! Project).compare(object2 as! Project)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
