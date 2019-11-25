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
            if _collection == nil, let id = id {
                readConn?.read { transaction in
                    self._collection = transaction.object(forKey: id, inCollection: Collection.collection) as? Collection
                }
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
            return AssetsByCollectionView.collectionId(from: group)
        }
        set {
            AbcFilteredByCollectionView.updateFilter(newValue)
            _collection = nil
        }
    }

    var group: String? {
        return mappings.allGroups.first
    }

    /**
     Should only ever be 0 or 1.
    */
    var sections: Int {
        return Int(mappings.numberOfSections())
    }

    var count: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }


    init() {
        readConn?.update(mappings: mappings)
    }


    // MARK: Public Methods

    func getAsset(_ indexPath: IndexPath) -> Asset? {
        var asset: Asset?

        readConn?.read { transaction in
            asset = (transaction.ext(AbcFilteredByCollectionView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Asset
        }

        return asset
    }

    func getAsset(_ row: Int) -> Asset? {
        return getAsset(IndexPath(row: row, section: 0))
    }

    func getIndexPath(_ asset: Asset) -> IndexPath? {
        var indexPath: IndexPath?

        readConn?.read { transaction in
            indexPath = (transaction.ext(AbcFilteredByCollectionView.name) as? YapDatabaseViewTransaction)?
                .indexPath(forKey: asset.id, inCollection: Asset.collection, with: self.mappings)
        }

        return indexPath
    }

    func yapDatabaseModified() -> ([YapDatabaseViewSectionChange], [YapDatabaseViewRowChange]) {
        guard let notifications = readConn?.beginLongLivedReadTransaction(),
            let viewConn = readConn?.ext(AbcFilteredByCollectionView.name) as? YapDatabaseViewConnection else {
                return ([], [])
        }

        if !viewConn.hasChanges(for: notifications) {
            readConn?.update(mappings: mappings)

            return ([], [])
        }

        return viewConn.getChanges(forNotifications: notifications, withMappings: mappings)
    }
}
