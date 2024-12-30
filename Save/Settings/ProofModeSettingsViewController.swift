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
        .onChange {  row in
            Settings.proofMode = row.value ?? false

            if Settings.proofMode {
                // Request location access used for fresh `PHAsset`s.
                LocationMananger.shared.requestAuthorization { status in

                    // Create key immediately, if not existing, so users can export right away.
                    if !(URL.proofModePrivateKey?.exists ?? false) {


                    }
                }
            }
        }

    }
}
