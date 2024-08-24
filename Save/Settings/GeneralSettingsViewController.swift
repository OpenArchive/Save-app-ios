//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

import OrbotKit
import Eureka
import IPtProxyUI
import LibProofMode
import SnapKit
import TorManager

class SectionHeaderView: UIView {
    let label = UILabel()
    let separator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.textAlignment = .left
        
        separator.backgroundColor = .saveLabelMuted
        
        self.addSubview(label)
        self.addSubview(separator)
        
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        separator.snp.makeConstraints { (make) in
            make.top.equalTo(label.snp.bottom)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.25)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GeneralSettingsViewController: Eureka.FormViewController, BridgesConfDelegate {
    
    private let compressionOptions = [
        NSLocalizedString("Higher quality", comment: ""),
        NSLocalizedString("Smaller size", comment: "")]
    
    private let interfaceStyleOptions = [
        NSLocalizedString("Device default", comment: ""),
        NSLocalizedString("Light", comment: ""),
        NSLocalizedString("Dark", comment: "")]
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.barStyle = .black
        
        setNeedsStatusBarAppearanceUpdate()
        
        form.delegate = nil

        if let lockAppRow = form.rowBy(tag: "lock_app") as? SwitchRow {
            lockAppRow.disabled = .init(booleanLiteral: Settings.proofModeEncryptedPassphrase != nil)
            lockAppRow.evaluateDisabled()
            lockAppRow.reload()
        }

        form.delegate = self
    }
    
    func sectionWithTitle(_ title: String) -> Section {
        return Section() { section in
            var header = HeaderFooterView<SectionHeaderView>(.class)
            header.height = {50}
            header.onSetupView = { (view, section) in
                view.label.attributedText = NSMutableAttributedString().sectionTitle(title)
            }
            section.header = header
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = .saveBackground
        tableView.separatorStyle = .none
        
        ActionSheetRow<String>.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .saveLabel
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .saveLabelMuted
            cell.detailTextLabel?.font = .normalMedium
        }
        
        ButtonRow.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .saveLabel
            cell.textLabel?.font = .normalMedium
        }
        
        PushRow<String>.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .saveLabel
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .saveLabelMuted
            cell.detailTextLabel?.font = .normalMedium
        }
        
        SwitchRow.defaultCellUpdate = { (cell, row) in
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .saveLabel
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .saveLabelMuted
            cell.detailTextLabel?.font = .normalSmall
            cell.switchControl.onTintColor = .saveHighlight
            cell.switchControl.thumbTintColor = .colorOnPrimary
        }
        
        // MARK: Secure
        //
        
        form
        +++ sectionWithTitle("Secure")

        form.last!
        <<< SwitchRow("lock_app") {
            $0.cellStyle = .subtitle
            $0.value = Settings.usePasscode
            $0.cell.textLabel?.numberOfLines = 0
            $0.title = NSLocalizedString("Lock app with passcode", comment: "")
        }
        .cellUpdate({ cell, row in
            if row.isDisabled && Settings.proofModeEncryptedPassphrase != nil {
                cell.detailTextLabel?.text = NSLocalizedString(
                    "You cannot disable this as long as you have your ProofMode key secured.",
                    comment: "")
            } 
//            else {
//                cell.detailTextLabel?.attributedText = NSMutableAttributedString()
//                    .normalSmall("Foo", color: .saveLabelMuted)
//            }
        })
        .onChange { [weak self] row in
            guard let strongSelf = self else { return }
            
            if row.value == true {
                strongSelf.presentSetPasscodeScreen()
            }
        }
        
        // MARK: Archive
        //
        form
        +++ sectionWithTitle("Archive")
        
        <<< PushRow<String>() {
            $0.cellStyle = .subtitle
            $0.cell.textLabel?.numberOfLines = 0
            $0.title = NSLocalizedString("Media Servers", comment: "")
        }
        .onCellSelection { (cell, row) in
            cell.setSelected(false, animated: true)
        }
        .cellUpdate { (cell, row) in
            cell.detailTextLabel?.attributedText = NSMutableAttributedString()
                .normalSmall("Manage your meda storage services", color: .saveLabelMuted)
        }
        .onCellSelection({ [weak self] (cell, row) in
            cell.setSelected(false, animated: true)
            
            let vc = SpaceTypeViewController()
            
            self?.present(vc, animated: true)
        })
        
        <<< ActionSheetRow<String>() {
            $0.selectorTitle = $0.title
            $0.options = compressionOptions
            $0.value = compressionOptions[Settings.highCompression ? 1 : 0]
            $0.cell.textLabel?.numberOfLines = 0
            $0.title = NSLocalizedString("Media Compression", comment: "")
        }
        .onCellSelection { (cell, row) in
            cell.setSelected(false, animated: true)
        }
        .onChange { row in
            Settings.highCompression = row.value == self.compressionOptions[1]
        }
        
        // MARK: Verify
        //
        +++ sectionWithTitle("Verify")

        <<< ButtonRow {
            $0.title = NSLocalizedString("ProofMode", comment: "")
            $0.presentationMode = .presentModally(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)
        }

        // MARK: Encrypt
        //
        +++ sectionWithTitle("Encrypt")

        <<< SwitchRow("isTorEnabled") {
            $0.disabled = true
            $0.title = String(format: NSLocalizedString("Transfer via %@ only (coming soon)", comment: ""), TorManager.torName)
            $0.value = Settings.useTor

            $0.cellStyle = .subtitle

            $0.cell.switchControl.onTintColor = .accent
            $0.cell.detailTextLabel?.numberOfLines = 0
            $0.cell.textLabel?.numberOfLines = 0
        }
        .cellUpdate({ cell, row in
            let str = String(
                format: NSLocalizedString(
                    "Enable %1$@ to protect your media in transit.",
                    comment: "Placeholder 1 is 'Tor'"),
                TorManager.torName)
            
            cell.detailTextLabel?.attributedText = NSMutableAttributedString()
                .normalSmall(str, color: .saveLabelMuted)
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

        // MARK: Bridge Configuration
        //
        <<< PushRow<String>() {
            $0.title = NSLocalizedString("Bridge Configuration",
                                         bundle: .iPtProxyUI,
                                         comment: "#bc-ignore!")
            $0.hidden = Condition.function(["isTorEnabled"], { (form) in
                return !((form.rowBy(tag: "isTorEnabled") as? SwitchRow)?.value ?? false)
            })
        }
        .onCellSelection({ [weak self] (cell, row) in
            guard !row.isDisabled else {
                return
            }

            cell.setSelected(false, animated: true)
            
            let vc = BridgesConfViewController()
            vc.delegate = self
            let navC = UINavigationController(rootViewController: vc)

            self?.present(navC, animated: true)
        })
        
        +++ sectionWithTitle("General")
        
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
        
        // MARK: Theme
        //
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
    
    @objc func didTapPrivacyPolicyButton() {
        if let url = URL(string: "https://open-archive.org/privacy") {
            UIApplication.shared.open(url, options: [:])
        }
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
    
    func presentSetPasscodeScreen(animated: Bool = true) {
        var options = ALOptions()
        options.isSensorsEnabled = false
        options.onSuccessfulDismiss = { (mode: ALMode?) in
            if let mode = mode {
                print("Password \(String(describing: mode))d successfully")
                Settings.usePasscode = true
                
                if let lockAppRow = self.form.rowBy(tag: "lock_app") as? SwitchRow {
                    lockAppRow.reload()
                }
            } else {
                print("User Cancelled")
                
                Settings.usePasscode = false
                
                if let lockAppRow = self.form.rowBy(tag: "lock_app") as? SwitchRow {
                    lockAppRow.value = false
                    lockAppRow.reload()
                }
            }
        }
        options.onFailedAttempt = { (mode: ALMode?) in
            print("Failed to \(String(describing: mode))")
        }
        
        AppLocker.present(with: .create, and: options, animated: animated)
    }
}
