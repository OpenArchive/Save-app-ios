//
//  SettingsViewModel.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import OrbotKit

class SettingsViewModel: ObservableObject {
    @Published var isPasscodeOn = AppSettings.isPasscodeEnabled
    @Published var isWifiOnlyOn = Settings.wifiOnly
    @Published var isOnionRoutingOn = false
    
    weak var delegate: ViewControllerNavigationDelegate?
    
    func navigateToServerList() {
        delegate?.pushServerList()
    }
    
    func navigateToFolderList() {
        
        delegate?.pushFolderList()
    }
    func navigateToProofMode(){
        let proofModeSettingsViewController = ProofModeSettingsViewController()
        delegate?.pushViewController(proofModeSettingsViewController)
    }
    
    func togglePasscode(_ value: Bool) {
        if value {
            let passcodeSetupController = PasscodeSetupController()
            delegate?.pushViewController(passcodeSetupController)
        }
    }
    
    
    func toggleOrbot(completion: @escaping (Bool) -> Void) {
        guard !isOnionRoutingOn else {
            OrbotManager.shared.stop()
            Settings.useOrbot = false
            isOnionRoutingOn = false
            completion(false)
            return
        }
        guard OrbotManager.shared.installed else {
            OrbotManager.shared.alertOrbotNotInstalled()
            Settings.useOrbot = false
            isOnionRoutingOn = false
            completion(false)
            return
        }
        if Settings.orbotApiToken.isEmpty {
            OrbotManager.shared.alertToken {
                OrbotManager.shared.start()
                Settings.useOrbot = true
                self.isOnionRoutingOn = true
                completion(true)
            }
        } else {
            OrbotManager.shared.start()
            Settings.useOrbot = true
            isOnionRoutingOn = true
            completion(true)
        }
    }
    
    func openOrbot() {
        OrbotKit.shared.open(.show)
    }
    
    func orbotTorStatus() -> String {
        if OrbotManager.shared.status == .started {
            if Settings.useTor {
                return NSLocalizedString("Tor enabled and connected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled and Tor connected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled but is connected", comment: "")
            }
        } else if OrbotManager.shared.status == .starting {
            if Settings.useTor {
                return NSLocalizedString("Tor is enabled and starting...", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled and Tor is starting...", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled but starting...", comment: "")
            }
        } else {
            if Settings.useTor {
                return NSLocalizedString("Tor is enabled but disconnected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled but Tor is disconnected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled and disconnected", comment: "")
            }
        }
    }
}
