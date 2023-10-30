//
//  GeneralSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import CleanInsightsSDK

class GeneralSettingsViewController: FormViewController {

    private static let compressionOptions = [
        NSLocalizedString("Better Quality", comment: ""),
        NSLocalizedString("Smaller Size", comment: "")]

    private static let campaignId = "upload_fails"

    private var consent: CampaignConsent? {
        CleanInsights.shared.consent(forCampaign: Self.campaignId)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("General", comment: "")

        form
        +++ Section(NSLocalizedString("Connectivity & Data", comment: ""))

        +++ Section("")
        <<< SwitchRow() {
            $0.title = NSLocalizedString("Only upload media when you are connected to Wi-Fi", comment: "")
            $0.value = Settings.wifiOnly

            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.switchControl.onTintColor = .accent
        }
        .onChange { row in
            Settings.wifiOnly = row.value ?? false

            NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
        }

        <<< PushRow<String>() {
            $0.title = NSLocalizedString("Media Compression", comment: "")
            $0.value = Self.compressionOptions[Settings.highCompression ? 1 : 0]

            $0.selectorTitle = $0.title
            $0.options = Self.compressionOptions

            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange { row in
            Settings.highCompression = row.value == Self.compressionOptions[1]
        }

        +++ Section(NSLocalizedString("Metadata", comment: ""))

        +++ Section("")
        <<< ButtonRow {
            $0.title = NSLocalizedString("ProofMode", comment: "")
            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)
        }

        +++ Section(NSLocalizedString("Security", comment: ""))

        +++ Section("")
        <<< SwitchRow() {
            $0.title = NSLocalizedString("Transfer via Orbot only", comment: "")
            $0.value = Settings.useOrbot

            $0.cellStyle = .subtitle

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
        .cellUpdate({ cell, row in
            cell.detailTextLabel?.text = NSLocalizedString("Orbot routes all traffic through the Tor network", comment: "")
        })
        .onChange { row in
            let newValue = row.value ?? false

            if newValue != Settings.useOrbot {
                if newValue {
                    if !OrbotManager.shared.installed {
                        row.value = false
                        row.updateCell()

                        OrbotManager.shared.alertOrbotNotInstalled()
                    }
                    else if Settings.orbotApiToken.isEmpty {
                        row.value = false
                        row.updateCell()

                        OrbotManager.shared.alertToken {
                            row.value = true
                            row.updateCell()

                            Settings.useOrbot = true
                            OrbotManager.shared.start()
                        }
                    }
                    else {
                        Settings.useOrbot = true
                        OrbotManager.shared.start()
                    }
                }
                else {
                    Settings.useOrbot = false
                    OrbotManager.shared.stop()
                }
            }
        }

        if SecureEnclave.deviceSecured() {
            form.last!
            <<< SwitchRow("lock_app") {
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

        form.last!
        <<< SwitchRow() {
            $0.title = NSLocalizedString("Allow 3rd-Party Keyboards", comment: "")
            $0.value = Settings.thirdPartyKeyboards

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange({ row in
            Settings.thirdPartyKeyboards = row.value ?? false
        })

        <<< SwitchRow() {
            $0.title = NSLocalizedString("Hide App Content when in Background", comment: "")
            $0.value = Settings.hideContent

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange({ row in
            Settings.hideContent = row.value ?? false
        })

        form
        +++ Section(NSLocalizedString("Health Checks", comment: ""))

        +++ Section("")
        <<< SwitchRow("health_checks") {
            $0.title = NSLocalizedString("Health Checks", comment: "")

            $0.cellStyle = .subtitle

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
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

                        self?.form.rowBy(tag: "health_checks")?.updateCell()
                    }
                    else {
                        row.value = false // Will trigger #onChange again with other path.
                    }
                }), animated: true)
            }
            else {
                CleanInsights.shared.deny(campaign: Self.campaignId)
                self?.form.rowBy(tag: "health_checks")?.updateCell()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        form.delegate = nil
        form.rowBy(tag: "health_checks")?.value = consent?.state == .granted || consent?.state == .notStarted
        form.delegate = self
    }
}