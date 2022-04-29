//
//  HealthCheckViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import CleanInsightsSDK

class HealthCheckViewController: FormViewController {

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

        navigationItem.title = NSLocalizedString("Health Checks", comment: "")

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        form.delegate = nil
        uploadFailsRow.value = consent?.state == .granted || consent?.state == .notStarted
        form.delegate = self
    }
}
