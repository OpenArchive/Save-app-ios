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


    private static let ID = "selected_space_id"

    private static var _id: String?

    static var id: String? {
        get {
            if _id == nil {
                _id = UserDefaults(suiteName: Constants.suiteName)?
                    .string(forKey: ID)
            }

            return _id
        }
        set {
            _id = newValue
            _space = nil // Invalidate cache.

            UserDefaults(suiteName: Constants.suiteName)?.set(_id, forKey: ID)

            // Update projects grouping to show projects of currently selected space.
            ProjectsView.updateGrouping()
        }
    }

    static var available: Bool {
        return id != nil
    }

    private static var _space: Space?

    static var space: Space? {
        get {
            if _space == nil,
                let id = id {
                Db.newLongLivedReadConn()?.read { transaction in
                    _space = transaction.object(
                        forKey: id, inCollection: Space.collection) as? Space
                }
            }

            return _space
        }
        set {
            id = newValue?.id
            _space = newValue
        }
    }
}
