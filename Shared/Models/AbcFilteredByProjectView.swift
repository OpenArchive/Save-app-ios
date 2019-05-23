//
//  AbcFilteredByProjectView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A child view of `AssetsByCollectionView` which can filter that by project.

 Use `updateFilter(:)` to engage filtering.
 */
@objc(AbcFilteredByProjectView)
class AbcFilteredByProjectView: YapDatabaseFilteredView {

    static let name = "assets_by_collection_filtered_by_project"

    private(set) static var projectId: String?

    /**
     A mapping which reverse sorts the groups by creation date of the collection
     they represent, due to the specific construction of the group key.

      See `AssetsByCollectionView#groupKey(for:)` for reference.
    */
    class func createMappings() -> YapDatabaseViewMappings {
        return YapDatabaseViewMappings(
            groupFilterBlock: { group, transaction in
                return true
        },
            sortBlock: { group1, group2, transaction in
                return group2.compare(group1)
        },
            view: name)
    }

    override init() {

        // No need to persist this, it changes way to often.
        let options = YapDatabaseViewOptions()
        options.isPersistent = false

        super.init(parentViewName: AssetsByCollectionView.name,
                   filtering: AbcFilteredByProjectView.getFilter(),
                   versionTag: nil, options: options)
    }

    /**
     Update filter to a new `projectId`.

     - parameter projectId: The project ID to filter by.
        `nil` will disable the filter and show all entries.
    */
    class func updateFilter(_ projectId: String? = nil) {
        AbcFilteredByProjectView.projectId = projectId
        Db.writeConn?.asyncReadWrite { transaction in
            (transaction.ext(name) as? YapDatabaseFilteredViewTransaction)?
                .setFiltering(getFilter(), versionTag: UUID().uuidString)
        }
    }

    /**
     - parameter projectId: The project ID to filter by.
     `nil` will disable the filter and show no entries.
     - returns: a filter block using the given projectId as criteria.
     */
    private class func getFilter() -> YapDatabaseViewFiltering {
        return YapDatabaseViewFiltering.withKeyBlock { _, group, _, _ in
            return AbcFilteredByProjectView.projectId != nil &&
                AssetsByCollectionView.projectId(from: group) == AbcFilteredByProjectView.projectId
        }
    }
}
