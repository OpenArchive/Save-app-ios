//
//  Settings.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Settings {

    private static let kFirstRunDone = "already_run"
    private static let kWifiOnly = "wifi_only"
    private static let kFirstFlaggedDone = "first_flagged_done"
    private static let kFirstBatchEditDone = "first_batch_edit_done"

    class var firstRunDone: Bool {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?.bool(forKey: kFirstRunDone)
                ?? false
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?.set(newValue, forKey: kFirstRunDone)
        }
    }

    class var wifiOnly: Bool {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?.bool(forKey: kWifiOnly) ?? false
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?.set(newValue, forKey: kWifiOnly)
        }
    }

    class var firstFlaggedDone: Bool {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?.bool(forKey: kFirstFlaggedDone) ?? false
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?.set(newValue, forKey: kFirstFlaggedDone)
        }
    }

    class var firstBatchEditDone: Bool {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?.bool(forKey: kFirstBatchEditDone) ?? false
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?.set(newValue, forKey: kFirstBatchEditDone)
        }
    }
}
