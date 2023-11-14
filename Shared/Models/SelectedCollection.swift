//
//  SelectedCollection.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 Helper class which is used in `PreviewViewController` and `EditViewController`
 to handle the common changes in assets of a user selected collection.
 */
class SelectedCollection {

    private var readConn = Db.newLongLivedReadConn()

    private var mappings = AbcFilteredByCollectionView.createMappings()

    private var _collection: Collection?
    var collection: Collection? {
        get {
            if _collection == nil {
                _collection = readConn?.object(for: id)
            }

            return _collection
        }
        set {
            AbcFilteredByCollectionView.updateFilter(newValue?.id)
            _collection = nil
        }
    }

    var id: String? {
        get {
            AssetsByCollectionView.collectionId(from: group)
        }
        set {
            AbcFilteredByCollectionView.updateFilter(newValue)
            _collection = nil
        }
    }

    var group: String? {
        mappings.allGroups.first
    }

    /**
     Should only ever be 0 or 1.
    */
    var sections: Int {
        Int(mappings.numberOfSections())
    }

    var count: Int {
        Int(mappings.numberOfItems(inSection: 0))
    }


    init() {
        readConn?.update(mappings: mappings)
    }


    // MARK: Public Methods

    func getAsset(_ indexPath: IndexPath) -> Asset? {
        readConn?.object(at: indexPath, in: mappings)
    }

    func getAsset(_ row: Int) -> Asset? {
        getAsset(IndexPath(row: row, section: 0))
    }

    func getIndexPath(_ asset: Asset) -> IndexPath? {
        readConn?.indexPath(of: asset, with: mappings)
    }

    func yapDatabaseModified() -> (forceFull: Bool, sectionChanges: [YapDatabaseViewSectionChange], rowChanges: [YapDatabaseViewRowChange]) {
        guard let notifications = readConn?.beginLongLivedReadTransaction(),
              let viewConn = readConn?.forView(AbcFilteredByCollectionView.name)
        else {
            return (false, [], [])
        }

        if !mappings.isNextSnapshot(notifications) || !viewConn.hasChanges(for: notifications) {
            readConn?.update(mappings: mappings)

            return (true, [], [])
        }

        let changes = viewConn.getChanges(forNotifications: notifications, withMappings: mappings)

        return (false, changes.sectionChanges, changes.rowChanges)
    }
}
