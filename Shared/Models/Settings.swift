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
    private static let kUsePasscode = "use_passcode"
    private static let kUseTor = "use_tor"
    private static let kOrbotApiToken = "orbotApiToken"
    private static let kUseOwnTor = "use_own_tor"
    private static let kProofMode = "proof_mode"
    private static let kProofModeEncryptedPassphrase = "proof_mode_encrypted_passphrase"
    private static let kFirstRunDone = "already_run"
    private static let kFirstAddDone = "first_add_done"
    private static let kFirstFlaggedDone = "first_flagged_done"
    private static let kFirstBatchEditDone = "first_batch_edit_done"
    private static let kIaShownFirstTime = "ia_shown_first_time"
    private static let kFirstUploadDone = "first_upload_done"
    private static let kThirdPartyKeyboards = "third_party_keyboards"
    private static let kHideContent = "hide_content"
    private static let kFirstFolderDone = "first_folder_done"
    private static let kInterfaceStyle = "interface_style"

    private class var defaults: UserDefaults? {
        UserDefaults(suiteName: Constants.suiteName)
    }

    // MARK: Operating Settings

    class var interfaceStyle: UIUserInterfaceStyle {
        get {
            let val = defaults?.integer(forKey: kInterfaceStyle) ?? 0
            return UIUserInterfaceStyle(rawValue: val) ?? .unspecified
        }
        set {
            defaults?.set(newValue.rawValue, forKey: kInterfaceStyle)
        }
    }
    
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

    /**
     We're not officially supporting Orbot anymore, since our users are confused by
     that.

     Hence this will always return `false`.
     However, we cannot ignore Orbot completely, since, if somebody has Orbot installed and
     running, we would run Tor-over-Tor which is not working mostly.

     So we keep this stuff around for now and for the case, that it might turn out, that our users aren't as
     confused as we thought, after all and want this feature back.
     */
    class var useOrbot: Bool {
        get {
            false //defaults?.bool(forKey: kUseTor) ?? false
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

    class var useTor: Bool {
        get {
            defaults?.bool(forKey: kUseOwnTor) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kUseOwnTor)
        }
    }
    
    class var usePasscode: Bool {
        get {
            defaults?.bool(forKey: kUsePasscode) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kUsePasscode)
            defaults?.synchronize()
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

    class var firstAddDone: Bool {
        get {
            defaults?.bool(forKey: kFirstAddDone) ?? false
        }
        set {
            defaults?.set(newValue, forKey: kFirstAddDone)
        }
    }

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
