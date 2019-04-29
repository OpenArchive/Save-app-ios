//
//  Bundle+displayName.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation

extension Bundle {

    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? "OpenArchive".localize()
    }
}
