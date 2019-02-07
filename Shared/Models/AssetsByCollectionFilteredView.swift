//
//  AssetsByCollectionFilteredView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class AssetsByCollectionFilteredView: YapDatabaseFilteredView {

    static let name = "assets_by_collection_filtered"

    override init() {
        super.init(parentViewName: AssetsByCollectionView.name,
                   filtering: AssetsByCollectionFilteredView.getFilter(),
                   versionTag: nil, options: nil)
    }

    class func getFilter(_ projectId: String? = nil) -> YapDatabaseViewFiltering {
        return YapDatabaseViewFiltering.withKeyBlock { transaction, group, collection, key in
            let groupProjectId = AssetsByCollectionView.projectId(from: group)

            return projectId == nil || groupProjectId == projectId
        }
    }

    class func updateFilter(_ projectId: String? = nil) {
        Db.writeConn?.readWrite { transaction in
            (transaction.ext(name) as? YapDatabaseFilteredViewTransaction)?
                .setFiltering(getFilter(projectId), versionTag: UUID().uuidString)
        }
    }
}
