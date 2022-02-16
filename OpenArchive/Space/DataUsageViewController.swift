//
//  DataUsageViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import IPtProxyUI

class DataUsageViewController: FormViewController, BridgesConfDelegate {

    private static let compressionOptions = [
        "Better Quality".localize(),
        "Smaller Size".localize()]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Data Usage".localize()

        form
        +++ SwitchRow() {
            $0.title = "Only upload media when you are connected to Wi-Fi".localize()
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.switchControl.onTintColor = .accent
            $0.value = Settings.wifiOnly
        }
        .onChange { row in
            Settings.wifiOnly = row.value ?? false

            NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
        }

        +++ AlertRow<String>() {
            $0.title = "Video/Image Compression".localize()
            $0.cell.textLabel?.numberOfLines = 0
            $0.selectorTitle = $0.title
            $0.options = DataUsageViewController.compressionOptions
            $0.value = DataUsageViewController.compressionOptions[Settings.highCompression ? 1 : 0]
        }
        .onChange { row in
            Settings.highCompression = row.value == DataUsageViewController.compressionOptions[1]
        }

        +++ SwitchRow() {
            $0.title = "Use Tor".localize()
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.switchControl.onTintColor = .accent
            $0.value = Settings.useTor
        }
        .onChange { row in
            let newValue = row.value ?? false

            if newValue != Settings.useTor {
                Settings.useTor = newValue

                if newValue {
                    TorManager.shared.start()
                }
                else {
                    TorManager.shared.stop()
                }

                NotificationCenter.default.post(name: .torUseChanged, object: newValue)
            }
        }

        +++ ButtonRow() {
            $0.title = "Tor Bridge Settings".localize()
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onCellSelection { [weak self] _, _ in
            let vc = BridgesConfViewController()
            vc.delegate = self

            self?.present(UINavigationController(rootViewController: vc), animated: true)
        }
    }


    // MARK: BridgesConfDelegate

    open var transport: Transport {
        get {
            return Settings.transport
        }
        set {
            Settings.transport = newValue
        }
    }

    open var customBridges: [String]? {
        get {
            Settings.customBridges
        }
        set {
            Settings.customBridges = newValue
        }
    }

    open func save() {
        TorManager.shared.reconfigureBridges()
    }
}
