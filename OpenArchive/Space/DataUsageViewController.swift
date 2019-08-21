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
        "Better Quality".localize(),
        "Smaller Size".localize()]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Data Usage".localize()

        form
            +++ SwitchRow() {
                $0.title = "Only upload media when you are connected to WiFi".localize()
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.switchControl.onTintColor = UIColor.accent
                $0.value = Settings.wifiOnly
            }
            .onChange { row in
                Settings.wifiOnly = row.value ?? false

                NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
            }

            +++ AlertRow<String>() {
                $0.title = "Video/Image Compression".localize()
                $0.selectorTitle = $0.title
                $0.options = DataUsageViewController.compressionOptions
                $0.value = DataUsageViewController.compressionOptions[Settings.highCompression ? 1 : 0]
            }
            .onChange { row in
                Settings.highCompression = row.value == DataUsageViewController.compressionOptions[1]
            }
    }
}
