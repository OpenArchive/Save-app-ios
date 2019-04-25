//
//  YapDatabaseConnection+updateMappings.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

extension YapDatabaseConnection {

    func update(mappings: YapDatabaseViewMappings) {
        self.read { transaction in
            mappings.update(with: transaction)
        }
    }
}
