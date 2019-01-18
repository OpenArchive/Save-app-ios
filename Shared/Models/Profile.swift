//
//  Profile.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 16.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Profile: NSObject {

    private static let ALIAS = "PROFILE_ALIAS"
    private static let ROLE = "PROFILE_ROLE"

    static var alias: String? {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?
                .string(forKey: Profile.ALIAS)
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?
                .set(newValue, forKey: Profile.ALIAS)
        }
    }

    static var role: String? {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?
                .string(forKey: Profile.ROLE)
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?
                .set(newValue, forKey: Profile.ROLE)
        }
    }
}
