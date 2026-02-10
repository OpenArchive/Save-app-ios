//
//  SelectedProject.swift
//  Save
//
//  Created by Navoda on 2026-02-05.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

class SelectedProject {
    private static let collection = "selected_project_id"
    private static let key = "current"

    private static var _project: Project?

    static var project: Project? {
        get {
            if _project == nil {
                Db.bgRwConn?.read { tx in
                    if let projectId = tx.object(forKey: key, inCollection: collection) as? String {
                        _project = tx.object(for: projectId, in: Project.collection)
                    }
                }
            }
            return _project
        }
        set {
            _project = newValue
        }
    }

    static func store(_ transaction: YapDatabaseReadWriteTransaction? = nil) {
        guard let transaction = transaction else {
            Db.writeConn?.asyncReadWrite(self.store)
            return
        }

        transaction.removeAllObjects(inCollection: collection)
        if let projectId = _project?.id {
            transaction.setObject(projectId, forKey: key, inCollection: collection)
        }
    }
}
