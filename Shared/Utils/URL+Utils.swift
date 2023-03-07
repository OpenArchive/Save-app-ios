//
//  URL+Utils.swift
//  Save
//
//  Created by Benjamin Erhart on 06.03.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Foundation

extension URL {

    var exists: Bool {
        (try? checkResourceIsReachable()) ?? false
    }

    var size: Int? {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
