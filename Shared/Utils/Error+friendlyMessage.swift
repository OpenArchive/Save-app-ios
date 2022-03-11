//
//  Error+friendlyMessage.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 19.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import FilesProvider

extension Error {

    var friendlyMessage: String {
        if let error = self as? FileProviderWebDavError {
            switch error.code {
            case .unauthorized:
                return NSLocalizedString("Incorrect username or password", comment: "")

            default:
                // For an unkown reason, casting self gives a better error
                // message, so that's actually not the same as the general
                // fallback below.
                return error.localizedDescription
            }
        }

        return localizedDescription
    }
}
