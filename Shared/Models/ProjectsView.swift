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

    private static let grouping = YapDatabaseViewGrouping.withObjectBlock {
        transaction, collection, key, object in
        
        if (object as? Project)?.spaceId == SelectedSpace.id {
            return Project.collection
        }

        return nil
    }

    private static let sorting = YapDatabaseViewSorting.withObjectBlock {
        transaction, group, collection1, key1, object1, collection2, key2, object2 in

        return (object1 as! Project).compare(object2 as! Project)
    }

    override init() {
        super.init(grouping: ProjectsView.grouping,
                   sorting: ProjectsView.sorting,
                   versionTag: UUID().uuidString, options: nil)
    }

    class func updateGrouping() {
        Db.writeConn?.asyncReadWrite { transaction in
            (transaction.ext(name) as? YapDatabaseAutoViewTransaction)?
                .setGrouping(grouping,
                             sorting: sorting,
                             versionTag: UUID().uuidString)
        }
    }
}
