//
//  ProjectsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

@objc(ProjectsView)
class ProjectsView: YapDatabaseAutoView {

    static let name = Project.collection

    static let groups = [Project.collection]

    private static let grouping = YapDatabaseViewGrouping.withObjectBlock {
        transaction, collection, key, object in

        // When nothing is selected (ShareExtension!), everything would match nil,
        // when using optional casting, so ensure cast before compare!
        if let project = object as? Project,
           project.spaceId == SelectedSpace.id
        {
            return Project.collection
        }

        return nil
    }

    private static let sorting = YapDatabaseViewSorting.withObjectBlock {
        transaction, group, collection1, key1, object1, collection2, key2, object2 in

        return (object1 as! Project).compare(object2 as! Project)
    }

    override init() {
        super.init(grouping: Self.grouping,
                   sorting: Self.sorting,
                   versionTag: UUID().uuidString, options: nil)
    }

    class func updateGrouping() {
        Db.writeConn?.asyncReadWrite { tx in
            (tx.ext(name) as? YapDatabaseAutoViewTransaction)?
                .setGrouping(grouping,
                             sorting: sorting,
                             versionTag: UUID().uuidString)
        }
    }
}
