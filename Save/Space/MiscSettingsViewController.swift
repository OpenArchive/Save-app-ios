//
//  MiscSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import CleanInsightsSDK
import LibProofMode

class MiscSettingsViewController: FormViewController {

    private static let campaignId = "upload_fails"

    private var consent: CampaignConsent? {
        CleanInsights.shared.consent(forCampaign: Self.campaignId)
    }

    private var uploadFailsRow = SwitchRow() {
        $0.title = NSLocalizedString("Health Checks", comment: "")
        $0.cellStyle = .subtitle
        $0.cell.switchControl.onTintColor = .accent
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.detailTextLabel?.numberOfLines = 0
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Miscellaneous", comment: "")

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
                        (self?.form.rowBy(tag: "lock_app") as? SwitchRow)?.value = true

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

        +++ uploadFailsRow
        .cellUpdate { [weak self] cell, row in
            let end = self?.consent?.end

            cell.detailTextLabel?.text = row.value == true && end != nil
                ? String(format: NSLocalizedString("Consent expires on %@.", comment: ""),
                         Formatters.format(end!))
                : NSLocalizedString("Help improve the app by running health checks when uploads fail.", comment: "")
        }
        .onChange { [weak self] row in
            if row.value == true {
                self?.navigationController?.pushViewController(ConsentViewController.new({ granted, _ in
                    if granted {
                        CleanInsights.shared.grant(campaign: Self.campaignId)
                        CleanInsights.shared.grant(feature: .lang)

                        self?.form.delegate = nil
                        row.value = true
                        self?.form.delegate = self

                        self?.uploadFailsRow.updateCell()
                    }
                    else {
                        row.value = false // Will trigger #onChange again with other path.
                    }
                }), animated: true)
            }
            else {
                CleanInsights.shared.deny(campaign: Self.campaignId)
                self?.uploadFailsRow.updateCell()
            }
        }

        +++ SwitchRow() {
            $0.title = NSLocalizedString("Allow 3rd-Party Keyboards", comment: "")
            $0.value = Settings.thirdPartyKeyboards
            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange({ row in
            Settings.thirdPartyKeyboards = row.value ?? false
        })

        +++ SwitchRow() {
            $0.title = NSLocalizedString("Hide App Content when in Background", comment: "")
            $0.value = Settings.hideContent
            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange({ row in
            Settings.hideContent = row.value ?? false
        })

        if SecureEnclave.deviceSecured() {
            form
            +++ SwitchRow("lock_app") {
                switch SecureEnclave.biometryType() {
                case .touchID:
                    $0.title = NSLocalizedString("Lock App with Touch ID or Device Passcode", comment: "")

                case .faceID:
                    $0.title = NSLocalizedString("Lock App with Face ID or Device Passcode", comment: "")

                default:
                    $0.title = NSLocalizedString("Lock App with Device Passcode", comment: "")
                }

                $0.value = SecureEnclave.loadKey() != nil
                $0.cell.switchControl.onTintColor = .accent
                $0.cell.textLabel?.numberOfLines = 0

                $0.disabled = .function(["proof_mode_key_encryption"], { form in
                    Settings.proofModeEncryptedPassphrase != nil
                })
            }
            .onChange { [weak self] row in
                let newValue: Bool

                if row.value ?? false {
                    newValue = SecureEnclave.createKey() != nil
                }
                else {
                    newValue = !SecureEnclave.removeKey()
                }

                // Seems, we can't create a key. Maybe running on a simulator?
                if newValue != row.value {
                    // Quirky way of disabling the onChange callback to avoid an endless loop.
                    self?.form.delegate = nil

                    row.value = newValue
                    row.updateCell()

                    row.disabled = true
                    row.evaluateDisabled()

                    self?.form.delegate = self // Enable callback again.

                    // Also disable this one.
                    if let pmkeRow = self?.form.rowBy(tag: "proof_mode_key_encryption") as? SwitchRow {
                        pmkeRow.value = false
                        pmkeRow.disabled = true
                        pmkeRow.evaluateDisabled()
                    }
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        form.delegate = nil
        uploadFailsRow.value = consent?.state == .granted || consent?.state == .notStarted
        form.delegate = self
    }
}
