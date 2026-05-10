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
    static var defaultFavIcon = UIImage(named: "private_server")?.withRenderingMode(.alwaysTemplate)


    private static let collection  = "selected_space"

    static var id: String? {
        space?.id
    }

    static var available: Bool {
        space != nil
    }

    private static var _space: Space?

    static var space: Space? {
        get {
            if _space == nil {
                Db.bgRwConn?.read { tx in
                    for id in tx.allKeys(inCollection: collection) {
                        _space = tx.object(for: id, in: Space.collection)

                        if _space != nil {
                            break
                        }
                    }

                    if _space == nil {
                        tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
                            _space = space
                            stop = true
                        }
                    }
                }
            }

            return _space
        }
        set {
            _space = newValue
        }
    }

    static func store(_ transaction: YapDatabaseReadWriteTransaction? = nil) {
        guard let transaction = transaction else {
            Db.writeConn?.asyncReadWrite { tx in
                self.store(tx)
                ProjectsView.updateGrouping(transaction: tx)
            }
            return
        }

        transaction.removeAllObjects(inCollection: collection)

        if let space = _space {
            transaction.setObject(space, forKey: space.id, inCollection: collection)
        }

        ProjectsView.updateGrouping(transaction: transaction)
    }
}
