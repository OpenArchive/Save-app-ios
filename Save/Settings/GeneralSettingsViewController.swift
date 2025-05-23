//
//  GeneralSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

import Eureka
import SnapKit
import OrbotKit

class SectionHeaderView: UIView {
    let label = UILabel()
    let separator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.textAlignment = .left
        
        separator.backgroundColor = .lightGray
        
        self.addSubview(label)
    
        label.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.bottom.equalToSuperview()
        }
        
        //        separator.snp.makeConstraints { (make) in
        //            make.top.equalTo(label.snp.bottom)
        //            make.bottom.equalToSuperview().inset(20)
        //            make.leading.trailing.equalToSuperview()
        //            make.height.equalTo(0.25)
        //        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GeneralSettingsViewController: FormViewController {
    
    private static let compressionOptions = [
        NSLocalizedString("Better Quality", comment: ""),
        NSLocalizedString("Smaller Size", comment: "")]
    
    private let interfaceStyleOptions = [
        NSLocalizedString("System", comment: ""),
        NSLocalizedString("Light", comment: ""),
        NSLocalizedString("Dark", comment: "")]
    
    private var isUpdatingSwitchProgrammatically = false
    
    @objc
    func orbotStatus(notification: Notification) {
        DispatchQueue.main.async {
            self.form.rowBy(tag: "orbot_status")?.reload()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDefaults()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(orbotStatus),
                                               name: .orbotStatus, object: nil)
        
        navigationItem.title = NSLocalizedString("General", comment: "")
        
        form
        +++ sectionWithTitle(NSLocalizedString("Connectivity & Data", comment: ""))
        
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
        
        //        <<< PushRow<String>() {
        //            $0.title = NSLocalizedString("Media Compression", comment: "")
        //            $0.value = Self.compressionOptions[Settings.highCompression ? 1 : 0]
        //
        //            $0.selectorTitle = $0.title
        //            $0.options = Self.compressionOptions
        //
        //            $0.cell.textLabel?.numberOfLines = 0
        //        }
        //        .onChange { row in
        //            Settings.highCompression = row.value == Self.compressionOptions[1]
        //        }
        
        +++ sectionWithTitle(NSLocalizedString("Meta Data", comment: ""))
        
        <<< ButtonRow("proofmode") {
            $0.title = NSLocalizedString("ProofMode", comment: "")

            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)

        }
        
        +++ sectionWithTitle(NSLocalizedString("Security", comment: ""))
        
        <<< SwitchRow() {
            $0.title = String(format: NSLocalizedString(
                "Transfer via %@ only", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
            $0.value = Settings.useOrbot

            $0.cellStyle = .subtitle

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
        .cellUpdate({ cell, row in
            cell.detailTextLabel?.text = String(format: NSLocalizedString(
                "%@ routes all traffic through the Tor network",
                comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
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
        
        <<< TextRow("orbot_status") {
            $0.value = getOrbotTorStatus()
            $0.cellStyle = .subtitle
        }.cellUpdate({ cell, row in
            cell.textField.text = self.getOrbotTorStatus()
        })

       
        // MARK: Theme
        +++ sectionWithTitle(NSLocalizedString("Presentation", comment: ""))
        <<< ActionSheetRow<String>() {
            $0.title = NSLocalizedString("Theme", comment: "")
            $0.value = interfaceStyleOptions[Settings.interfaceStyle.rawValue]
            $0.options = interfaceStyleOptions
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onCellSelection { (cell, row) in
            cell.setSelected(false, animated: true)
        }
        .onChange { row in
            if row.value == self.interfaceStyleOptions[1] {
                Utils.setLightMode()
            } else if row.value == self.interfaceStyleOptions[2] {
                Utils.setDarkMode()
            } else {
                Utils.setUnspecifiedMode()
            }
        }
       
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        //        form.delegate = nil
        //
        //        if let lockAppRow = form.rowBy(tag: "lock_app") as? SwitchRow {
        //            lockAppRow.value = AppPreferences.passcodeEnabled
        //            lockAppRow.evaluateDisabled()
        //            lockAppRow.reload()
        //        }
        
        form.delegate = self
    }
    
    private func getOrbotTorStatus() -> String {
        if OrbotManager.shared.status == .started {
            if Settings.useTor {
                return NSLocalizedString("Tor enabled and connected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled and Tor connected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled but is connected", comment: "")
            }
        } else if OrbotManager.shared.status == .starting {
                if Settings.useTor {
                    return NSLocalizedString("Tor is enabled and starting...", comment: "")
                } else if Settings.useOrbot {
                    return NSLocalizedString("Orbot enabled and Tor is starting...", comment: "")
                } else {
                    return NSLocalizedString("Tor is not enabled but starting...", comment: "")
                }
        } else {
            if Settings.useTor {
                return NSLocalizedString("Tor is enabled but disconnected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled but Tor is disconnected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled and disconnected", comment: "")
            }
        }
    }
    
    func sectionWithTitle(_ title: String) -> Section {
        return Section() { section in
            var header = HeaderFooterView<SectionHeaderView>(.class)
            header.height = {40}
            header.onSetupView = { (view, section) in
                view.label.attributedText = NSMutableAttributedString().sectionTitle(title)
            }
            section.header = header
        }
    }
    
    func setupDefaults() {
        ActionSheetRow<String>.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .systemFont(ofSize: 16)
            cell.detailTextLabel?.textColor = .lightGray
            cell.detailTextLabel?.font = .normalMedium
        }
        
        ButtonRow.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .normalMedium
        }
        
        PushRow<String>.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .lightGray
            cell.detailTextLabel?.font = .normalMedium
        }
        
        TextRow.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .lightGray
            cell.detailTextLabel?.font = .normalMedium
            cell.titleLabel?.textColor = .lightGray
            cell.titleLabel?.font = .normalMedium
            cell.textField?.textColor = .lightGray
            cell.textField?.font = .normalMedium
        }
        
        SwitchRow.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .lightGray
            cell.detailTextLabel?.font = .normalSmall
            cell.switchControl.onTintColor = .saveHighlight
            cell.switchControl.thumbTintColor = .colorOnPrimary
        }
    }
    
    /// Updates the switch row value programmatically while suppressing `onChange`.
    private func updateSwitch(row: SwitchRow, value: Bool) {
        isUpdatingSwitchProgrammatically = true
        row.value = value
        row.updateCell()
        isUpdatingSwitchProgrammatically = false
    }
}
