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
import OrbotKit
import IPtProxyUI
import TorManager

class GeneralSettingsViewController: FormViewController, BridgesConfDelegate {

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

        <<< ButtonRow {
            $0.title = NSLocalizedString("ProofMode", comment: "")
            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)
        }

        +++ Section(NSLocalizedString("Security", comment: ""))

        <<< SwitchRow() {
            $0.title = String(format: NSLocalizedString("Transfer via %@ only", comment: ""), TorManager.torName)
            $0.value = Settings.useTor

            $0.cellStyle = .subtitle

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
        .cellUpdate({ cell, row in
            cell.detailTextLabel?.text = String(
                format: NSLocalizedString(
                    "Enable %1$@ to protect your media in transit.",
                    comment: "Placeholder 1 is 'Tor'"),
                TorManager.torName)
        })
        .onChange({ [weak self] row in
            let newValue = row.value ?? false

            guard newValue != Settings.useTor else {
                return
            }

            if newValue {
                guard let self = self else {
                    return
                }

                AlertHelper.present(
                    self,
                    message: String(
                        format: NSLocalizedString(
                            "Please disable or uninstall any other %1$@ apps or services.",
                            comment: "Placeholder 1 is 'Tor'"),
                        TorManager.torName) + "\n\n",
                    title: nil,
                    actions: [
                        AlertHelper.defaultAction(handler: { _ in
                            Settings.useTor = true

                            if !TorManager.shared.connected {
                                // Trigger display of `TorStartViewController` to start Tor.
                                if let navC = self.navigationController as? MainNavigationController {
                                    navC.setRoot()
                                }
                            }
                        }),
                        AlertHelper.cancelAction(handler: { _ in
                            row.value = Settings.useTor
                            row.updateCell()
                        })
                    ])
            }
            else {
                Settings.useTor = false
                TorManager.shared.stop()
            }
        })

        <<< ButtonRow() {
            $0.title = NSLocalizedString("Bridge Configuration", bundle: .iPtProxyUI, comment: "#bc-ignore!")
        }
        .onCellSelection({ [weak self] _, row in
            guard !row.isDisabled else {
                return
            }

            let vc = BridgesConfViewController()
            vc.delegate = self
            let navC = UINavigationController(rootViewController: vc)

            self?.present(navC, animated: true)
        })

        +++ Section()

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

                $0.cellStyle = .subtitle

                $0.cell.switchControl.onTintColor = .accent
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.detailTextLabel?.numberOfLines = 0
            }
            .cellUpdate({ cell, row in
                if row.isDisabled && Settings.proofModeEncryptedPassphrase != nil {
                    cell.detailTextLabel?.text = NSLocalizedString(
                        "You cannot disable this as long as you have your ProofMode key secured.",
                        comment: "")
                }
                else {
                    cell.detailTextLabel?.text = nil
                }
            })
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
                }

                // Fix spacing issues due to changes in number of displayed text lines.
                row.reload()
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

        if let lockAppRow = form.rowBy(tag: "lock_app") as? SwitchRow {
            lockAppRow.value = SecureEnclave.loadKey() != nil

            lockAppRow.disabled = .init(booleanLiteral: Settings.proofModeEncryptedPassphrase != nil)
            lockAppRow.evaluateDisabled()

            // Fix spacing issues due to changes in number of displayed text lines.
            lockAppRow.reload()
        }

        form.delegate = self
    }


    // MARK: BridgesConfDelegate

    var transport: IPtProxyUI.Transport {
        get {
            IPtProxyUI.Settings.transport
        }
        set {
            IPtProxyUI.Settings.transport = newValue
        }
    }

    var customBridges: [String]? {
        get {
            IPtProxyUI.Settings.customBridges
        }
        set {
            IPtProxyUI.Settings.customBridges = newValue
        }
    }

    func save() {
        DispatchQueue.global(qos: .userInitiated).async {
            TorManager.shared.reconfigureBridges()
        }
    }
}
