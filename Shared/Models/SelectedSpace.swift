//
//  SelectedSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class SelectedSpace {

    /**
     The default favIcon to show, when there's no space, yet or the we couldn't
     acquire a favIcon for that space.
     */
    static var defaultFavIcon = UIImage(named: "server")


    private static let collection  = "selected_space"

    static var id: String? {
        get {
            return space?.id
        }
    }

    static var available: Bool {
        return id != nil
    }

    private static var _space: Space?

    static var space: Space? {
        if _space == nil {
            Db.bgRwConn?.read { transaction in
                for id in transaction.allKeys(inCollection: SelectedSpace.collection) {
                    self._space = transaction.object(
                        forKey: id, inCollection: Space.collection) as? Space

                    if self._space != nil {
                        break
                    }
                }

                if self._space == nil {
                    transaction.enumerateKeysAndObjects(inCollection: Space.collection) { key, object, stop in
                        if let space = object as? Space {
                            self._space = space
                            stop.pointee = true
                        }
                    }
                }
            }
        }

        return _space
    }

    static func setSpace(_ space: Space?, _ transaction: YapDatabaseReadWriteTransaction? = nil) {
        guard let transaction = transaction else {
            Db.bgRwConn?.asyncReadWrite { transaction in
                self.setSpace(space, transaction)
            }

            return
        }

        _space = space

        transaction.removeAllObjects(inCollection: SelectedSpace.collection)

        if let space = _space {
            // We just need any serializable object to store here, otherwise
            // when sending nil, nothing is stored.
            // That object is never read. The original space is always read instead!
            transaction.setObject(space, forKey: space.id, inCollection: SelectedSpace.collection)
        }

        // Update projects grouping to show projects of currently selected space.
        DispatchQueue.main.async {
            ProjectsView.updateGrouping()
        }
    }
}
