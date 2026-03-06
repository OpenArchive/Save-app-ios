//
//  UIBackgroundFetchResult+description.swift
//  Save
//
//  Created by Benjamin Erhart on 09.05.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Foundation
import UIKit

extension UIBackgroundFetchResult {

    public var debugDescription: String {
        switch self {
        case .newData:
            return "newData"

        case .noData:
            return "noData"

        case .failed:
            return "failed"

        @unknown default:
            return "result \(rawValue)"
        }
    }
}
