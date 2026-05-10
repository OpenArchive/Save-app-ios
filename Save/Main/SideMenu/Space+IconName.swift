//
//  Space+IconName.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

extension Space {
    var iconName: String {
        self is IaSpace ? "internet_archive" : "private_server"
    }
}
