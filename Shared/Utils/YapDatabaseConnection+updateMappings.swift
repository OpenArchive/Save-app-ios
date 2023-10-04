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
        read { transaction in
            mappings.update(with: transaction)
        }
    }

    func readInView(_ viewName: String?, _ block: (_ viewTransaction: YapDatabaseViewTransaction?, _ transaction: YapDatabaseReadTransaction) -> Void) {
        read { transaction in
            if let viewName = viewName {
                block(transaction.ext(viewName) as? YapDatabaseViewTransaction, transaction)
            }
            else {
                block(nil, transaction)
            }
        }
    }
}
