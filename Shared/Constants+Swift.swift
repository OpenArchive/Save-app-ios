//
//  Constants+Swift.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation

extension Constants {

    class var appGroup: String {
        return __appGroup as String
    }

    class var teamId: String {
        return __teamId as String
    }

    /**
     Fix for spurious warning.
     See https://forums.developer.apple.com/thread/51348#discussion-186721
     */
    class var suiteName: String {
        return  "\(teamId).\(appGroup)"
    }

    class var testBackgroundUpload: Bool {
        #if DEBUG
            return false
        #else
            return false
        #endif
    }
}
