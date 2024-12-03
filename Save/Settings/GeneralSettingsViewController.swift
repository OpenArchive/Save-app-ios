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

class SectionHeaderView: UIView {
    let label = UILabel()
    let separator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.textAlignment = .left
        
        separator.backgroundColor = .lightGray
        
        self.addSubview(label)
//        self.addSubview(separator)
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDefaults()
        
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
        +++ sectionWithTitle(NSLocalizedString("Secure", comment: ""))
        <<< SwitchRow("lock_app") {
            $0.title = NSLocalizedString("Lock App with passcode", comment: "")
            $0.value = SecureEnclave.loadKey() != nil
            $0.disabled = .init(booleanLiteral: Settings.proofModeEncryptedPassphrase != nil)
            $0.cell.textLabel?.numberOfLines = 0
        }
        .onChange { row in
            if row.value == true {
                let pinCreateController = PasscodeSetupController()
                self.navigationController?.pushViewController(pinCreateController, animated: true)
            } else {
                let keyRemoved = SecureEnclave.removeKey()
                UserDefaults.standard.set("", forKey: "encryptedAppPin")
                
                if keyRemoved {
                    print("Secure key successfully removed.")
                } else {
                    print("Failed to remove the secure key.")
                }
            }
            row.evaluateDisabled()
        }

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        form.delegate = nil
        
        if let lockAppRow = form.rowBy(tag: "lock_app") as? SwitchRow {
            lockAppRow.value = SecureEnclave.loadKey() != nil
            lockAppRow.evaluateDisabled()
            lockAppRow.reload()
        }
        
        form.delegate = self
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
}
