//
//  YapDatabaseViewMappings+isNextSnapshot.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.04.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import YapDatabase

extension YapDatabaseViewMappings {

    func isNextSnapshot(_ notifications: [Notification]) -> Bool {
        guard snapshotOfLastUpdate < .max else {
            return false
        }

        let firstSnapshot = (notifications.first?.userInfo?[YapDatabaseSnapshotKey] as? NSNumber)?.uint64Value

        return snapshotOfLastUpdate + 1 == firstSnapshot
    }
}
