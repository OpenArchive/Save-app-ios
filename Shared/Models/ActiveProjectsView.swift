//
//  ActiveProjectsView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 26.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

@objc(ActiveProjectsView)
class ActiveProjectsView: YapDatabaseFilteredView {

    static let name = "active_projects"

    static let groups = ProjectsView.groups

    override init() {
        let filter = YapDatabaseViewFiltering.withObjectBlock { _, _, _, _, object in
            return (object as? Project)?.active ?? false
        }

        super.init(parentViewName: ProjectsView.name,
                   filtering: filter,
                   versionTag: nil, options: nil)
    }
}
