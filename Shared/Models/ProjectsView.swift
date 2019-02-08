//
//  ProjectsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class ProjectsView: YapDatabaseAutoView {

    static let name = Project.collection

    static let groups = [Project.collection]

    static var mappings = YapDatabaseViewMappings(groups: groups, view: name)

    override init() {
        let grouping = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            return Project.collection == collection ? collection : nil
        }

        let sorting = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, object1, collection2, key2, object2 in

            return (object1 as! Project).compare(object2 as! Project)
        }

        super.init(grouping: grouping, sorting: sorting, versionTag: nil, options: nil)
    }
}
