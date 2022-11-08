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

class MiscSettingsViewController: FormViewController {

    private static let campaignId = "upload_fails"

    private var consent: CampaignConsent? {
        CleanInsights.shared.consent(forCampaign: Self.campaignId)
    }

    private var uploadFailsRow = SwitchRow() {
        $0.title = NSLocalizedString("Health Checks", comment: "")
        $0.cellStyle = .subtitle
        $0.cell.detailTextLabel?.numberOfLines = 0
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Miscellaneous", comment: "")

        form
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
                self?.navigationController?.pushViewController(ConsentViewController.new({ granted in
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
        }
        .onChange({ row in
            Settings.thirdPartyKeyboards = row.value ?? false
        })

        if SecureEnclave.deviceSecured() {
            form
            +++ SwitchRow() {
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
