//
//  SettingsViewModel.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


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

    func navigateToProofMode() {
        if #available(iOS 14.0, *) {
            delegate?.pushViewController(ProofModeSettingsViewController())
        }
    }

    func togglePasscode(_ value: Bool) {
        if value {
            let passcodeSetupController = PasscodeSetupController()
            delegate?.pushViewController(passcodeSetupController)
        }
    }
}
