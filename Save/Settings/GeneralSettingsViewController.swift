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
        
        label.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.bottom.equalToSuperview()
        }
        
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
        
        +++ sectionWithTitle(NSLocalizedString("Meta Data", comment: ""))
        
        <<< ButtonRow("proofmode") {
            $0.title = NSLocalizedString("ProofMode", comment: "")

            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)

        }

       
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
        
        form.delegate = nil
        
//        if let lockAppRow = form.rowBy(tag: "lock_app") as? SwitchRow {
//            lockAppRow.value = SecureEnclave.loadKey() != nil
//            
//            lockAppRow.disabled = .init(booleanLiteral: Settings.proofModeEncryptedPassphrase != nil)
//            lockAppRow.evaluateDisabled()
//            
//            // Fix spacing issues due to changes in number of displayed text lines.
//            lockAppRow.reload()
//        }
        
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
