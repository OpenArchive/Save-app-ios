//
//  DataUsageViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class DataUsageViewController: FormViewController {

    private static let compressionOptions = [
        NSLocalizedString("Better Quality", comment: ""),
        NSLocalizedString("Smaller Size", comment: "")]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Data Usage", comment: "")

        form
        +++ SwitchRow() {
            $0.title = NSLocalizedString("Only upload media when you are connected to Wi-Fi", comment: "")
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.switchControl.onTintColor = .accent
            $0.value = Settings.wifiOnly
        }
        .onChange { row in
            Settings.wifiOnly = row.value ?? false

            NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
        }

        +++ AlertRow<String>() {
            $0.title = NSLocalizedString("Video/Image Compression", comment: "")
            $0.cell.textLabel?.numberOfLines = 0
            $0.selectorTitle = $0.title
            $0.options = DataUsageViewController.compressionOptions
            $0.value = DataUsageViewController.compressionOptions[Settings.highCompression ? 1 : 0]
        }
        .onChange { row in
            Settings.highCompression = row.value == DataUsageViewController.compressionOptions[1]
        }

        +++ SwitchRow() {
            $0.title = NSLocalizedString("Transfer via Orbot only", comment: "")
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.switchControl.onTintColor = .accent
            $0.value = Settings.useOrbot
        }
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
    }
}
