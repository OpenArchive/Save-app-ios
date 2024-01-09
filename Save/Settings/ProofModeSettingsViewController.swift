//
//  ProofModeSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import LibProofMode

class ProofModeSettingsViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("ProofMode", comment: "")

        form
        +++ SwitchRow("proof_mode") {
            $0.title = NSLocalizedString("Enable ProofMode", comment: "")
            $0.value = Settings.proofMode
            $0.cellStyle = .subtitle
            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
        .cellUpdate { cell, _ in
            cell.detailTextLabel?.text = NSLocalizedString("Capture extra metadata and notarize all media.", comment: "")
        }
        .onChange { [weak self] row in
            Settings.proofMode = row.value ?? false

            // Create key immediately, if not existing, so users can export right away.
            if Settings.proofMode && !(URL.proofModePrivateKey?.exists ?? false) {

                // If this is the first time, we create the key securely right away.
                if Settings.proofModeEncryptedPassphrase == nil {
                    if let pmkeRow = self?.form.rowBy(tag: "proof_mode_key_encryption") as? SwitchRow {
                        pmkeRow.value = true
                        pmkeRow.updateCell()
                    }
                }

                Proof.shared.initializeWithDefaultKeys()

                self?.form.rowBy(tag: "proof_mode_key_share")?.evaluateDisabled()
            }
        }

        if SecureEnclave.deviceSecured() {
            form
            +++ SwitchRow("proof_mode_key_encryption") {
                switch SecureEnclave.biometryType() {
                case .touchID:
                    $0.title = NSLocalizedString("Secure ProofMode Key with Touch ID or Device Passcode", comment: "")

                case .faceID:
                    $0.title = NSLocalizedString("Secure ProofMode Key with Face ID or Device Passcode", comment: "")

                default:
                    $0.title = NSLocalizedString("Secure ProofMode Key with Device Passcode", comment: "")
                }
                $0.value = Settings.proofModeEncryptedPassphrase != nil && SecureEnclave.loadKey() != nil
                $0.cellStyle = .subtitle
                $0.cell.switchControl.onTintColor = .accent
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.detailTextLabel?.numberOfLines = 0
            }
            .cellUpdate { cell, _ in
                cell.detailTextLabel?.text = NSLocalizedString(
                    "Changing this will create a new key! If you exported and signed that one before, you will need to do it again with the new one.",
                    comment: "")
            }
            .onChange { [weak self] row in
                let update = { (passphrase: String?) in
                    for file in [URL.proofModePrivateKey, URL.proofModePublicKey] {
                        if let file = file {
                            try? FileManager.default.removeItem(at: file)
                        }
                    }

                    Proof.shared.passphrase = passphrase
                    Proof.shared.initializeWithDefaultKeys()

                    self?.form.rowBy(tag: "proof_mode_key_share")?.evaluateDisabled()
                }

                if row.value ?? false {
                    var key = SecureEnclave.loadKey()

                    if key == nil {
                        // Force key creation.
                        SecureEnclave.createKey()

                        key = SecureEnclave.loadKey()
                    }

                    if let key = key, Settings.proofModeEncryptedPassphrase == nil {
                        let passphrase = UUID().uuidString

                        Settings.proofModeEncryptedPassphrase = SecureEnclave.encrypt(passphrase, with: SecureEnclave.getPublicKey(key))
                        let decryptedPassphrase = SecureEnclave.decrypt(Settings.proofModeEncryptedPassphrase, with: key)

                        // Test, if encryption works correctly, if not, don't destroy old key.
                        if passphrase == decryptedPassphrase {
                            update(passphrase)
                        }
                        else {
                            Settings.proofModeEncryptedPassphrase = nil

                            row.value = false
                            row.updateCell()
                        }
                    }
                }
                else {
                    if Settings.proofModeEncryptedPassphrase != nil {
                        Settings.proofModeEncryptedPassphrase = nil
                        update(nil)
                    }
                }
            }
        }

        form
        +++ ButtonRow("proof_mode_key_share") {
            $0.title = NSLocalizedString("Share ProofMode Public Key", comment: "")
            $0.disabled = .function([], { form in
                !(URL.proofModePublicKey?.exists ?? false)
            })
        }
        .onCellSelection({ [weak self] cell, row in
            guard let file = URL.proofModePublicKey, file.exists else {
                return
            }

            let vc = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = cell

            self?.present(vc, animated: true)
        })
    }
}
