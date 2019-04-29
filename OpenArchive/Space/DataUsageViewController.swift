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
    }
}
