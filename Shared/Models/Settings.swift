//
//  Settings.swift
//  Save
//
//  Created by Benjamin Erhart on 29.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Settings {

    private static let kWifiOnly = "wifi_only"
    private static let kHighCompression = "high_compression"
    private static let kUseTor = "use_tor"
    private static let kOrbotApiToken = "orbotApiToken"
    private static let kTransport = "transport"
    private static let kCustomBridges = "custom_bridges"
    private static let kProofMode = "proof_mode"
    private static let kProofModeEncryptedPassphrase = "proof_mode_encrypted_passphrase"
    private static let kFirstRunDone = "already_run"
    private static let kFirstFlaggedDone = "first_flagged_done"
    private static let kFirstBatchEditDone = "first_batch_edit_done"
    private static let kIaShownFirstTime = "ia_shown_first_time"
    private static let kFirstUploadDone = "first_upload_done"
    private static let kThirdPartyKeyboards = "third_party_keyboards"
    private static let kHideContent = "hide_content"
    private static let kFirstFolderDone = "first_folder_done"

    private class var defaults: UserDefaults? {
        UserDefaults(suiteName: Constants.suiteName)
    }

    // MARK: Operating Settings

    class var wifiOnly: Bool {
        get {
            defaults?.bool(forKey: kWifiOnly) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kWifiOnly)
        }
    }

    class var highCompression: Bool {
        get {
            defaults?.bool(forKey: kHighCompression) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kHighCompression)
        }
    }

    class var useOrbot: Bool {
        get {
            defaults?.bool(forKey: kUseTor) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kUseTor)
        }
    }

    class var orbotApiToken: String {
        get {
            defaults?.string(forKey: kOrbotApiToken) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: kOrbotApiToken)
        }
    }

    class var customBridges: [String]? {
        get {
            defaults?.stringArray(forKey: kCustomBridges)
        }
        set {
            defaults?.set(newValue, forKey: kCustomBridges)
        }
    }

    class var proofMode: Bool {
        get {
            defaults?.bool(forKey: kProofMode) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kProofMode)
        }
    }

    class var proofModeEncryptedPassphrase: Data? {
        get {
            defaults?.data(forKey: kProofModeEncryptedPassphrase)
        }
        set {
            defaults?.set(newValue, forKey: kProofModeEncryptedPassphrase)
        }
    }

    class var thirdPartyKeyboards: Bool {
        get {
            defaults?.bool(forKey: kThirdPartyKeyboards) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kThirdPartyKeyboards)
        }
    }

    class var hideContent: Bool {
        get {
            defaults?.bool(forKey: kHideContent) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kHideContent)
        }
    }


    // MARK: First run wizard.

    class var firstRunDone: Bool {
        get {
            defaults?.bool(forKey: kFirstRunDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstRunDone)
        }
    }


    // MARK: InfoAlerts

    class var firstFlaggedDone: Bool {
        get {
            defaults?.bool(forKey: kFirstFlaggedDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstFlaggedDone)
        }
    }

    class var firstBatchEditDone: Bool {
        get {
            defaults?.bool(forKey: kFirstBatchEditDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstBatchEditDone)
        }
    }

    class var iaShownFirstTime: Bool {
        get {
            defaults?.bool(forKey: kIaShownFirstTime) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kIaShownFirstTime)
        }
    }

    class var firstUploadDone: Bool {
        get {
            defaults?.bool(forKey: kFirstUploadDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstUploadDone)
        }
    }

    class var firstFolderDone: Bool {
        get {
            defaults?.bool(forKey: kFirstFolderDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstFolderDone)
        }
    }
}
