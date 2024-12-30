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
    
    weak var delegate: GeneralSettingsDelegate?

       func navigateToAnotherViewController() {
           delegate?.pushServerListScreen()
       }
    func navigateToFolderList() {
      
        delegate?.pushFoldersScreen()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDefaults()
        
    //    navigationItem.title = NSLocalizedString("General", comment: "")
        
        form
        +++ sectionWithTitle(NSLocalizedString("Secure", comment: ""))
        <<< SwitchRow() {
            $0.title = NSLocalizedString("Lock app with passcode", comment: "")
          
            $0.cell.switchControl.onTintColor = .accent
        }
        
        .onChange { row in
           
        }
        +++ sectionWithTitle(NSLocalizedString("Archive", comment: ""))
        <<< SubtitleRow() {
               $0.title = NSLocalizedString("Media Servers", comment: "")
               $0.value = NSLocalizedString("Add or remove media servers", comment: "")
           }
           .onCellSelection { _, row in
               self.navigateToAnotherViewController()
            
           }
        <<< SubtitleRow() {
               $0.title = NSLocalizedString("Media Folders", comment: "")
               $0.value = NSLocalizedString("Add or remove media folders", comment: "")
           }
           .onCellSelection { _, row in
               self.navigateToFolderList()
            
           }
                <<< PushRow<String>() {
                    $0.title = NSLocalizedString("Media Compression", comment: "")
                    $0.value = Self.compressionOptions[Settings.highCompression ? 1 : 0]
        
                    $0.selectorTitle = $0.title
                    $0.options = Self.compressionOptions
        
                    $0.cell.textLabel?.numberOfLines = 0
                }
                .onChange { row in
                    Settings.highCompression = row.value == Self.compressionOptions[1]
                }
        +++ sectionWithTitle(NSLocalizedString("Verify", comment: ""))
        
        <<< ButtonRow("proofmode") {
            $0.title = NSLocalizedString("ProofMode", comment: "")

            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                ProofModeSettingsViewController()
            }), onDismiss: nil)

        }
        +++ sectionWithTitle(NSLocalizedString("Encrypt", comment: ""))
        <<< SwitchRow() {
            $0.title = NSLocalizedString("Turn on Onion Routing", comment: "")
            $0.cellStyle = .subtitle
            $0.cell.switchControl.onTintColor = .accent
            $0.cell.textLabel?.numberOfLines = 0
            $0.cell.detailTextLabel?.numberOfLines = 0
        }
        .cellUpdate { cell, _ in
            cell.detailTextLabel?.text = NSLocalizedString("Transfer via the Tor Network only", comment: "")
        }
        .onChange { row in
           
        }
        +++ sectionWithTitle(NSLocalizedString("Genaral", comment: ""))
      
        
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
        +++ sectionWithTitle(NSLocalizedString("About", comment: ""))
     
        <<< SubtitleRow() {
               $0.title = NSLocalizedString("Terms and Privacy Policy", comment: "")
               $0.value = NSLocalizedString("Tap to view our Terms and Privacy Policy", comment: "")
           }
           .onCellSelection { _, row in
               print("Row tapped: \(row.title ?? "")")
           }
        <<< SubtitleRow() {
               $0.title = NSLocalizedString("Version", comment: "")
               $0.value = String(format: NSLocalizedString("Version %1$@, build %2$@", comment: ""),
                                 Bundle.main.version, Bundle.main.build)
           }
           .onCellSelection { _, row in
               print("Row tapped: \(row.title ?? "")")
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
        LabelRow.defaultCellUpdate = { (cell, row) in
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
            cell.textLabel?.textColor = .gray
            cell.textLabel?.font = .normalMedium
            cell.detailTextLabel?.textColor = .lightGray
            cell.detailTextLabel?.font = .normalSmall
            cell.switchControl.onTintColor = .saveHighlight
            cell.switchControl.thumbTintColor = .colorOnPrimary
        }
    }
}
import Eureka

// Custom Cell for Title and Subtitle
import Eureka

// Custom Cell to Display Title and Subtitle Vertically
final class SubtitleCell: Cell<String>, CellType {
    
    required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier) // Enforce .subtitle style
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func setup() {
        super.setup()
        selectionStyle = .default // Makes the row tappable
        
        // Title Configuration
      
        textLabel?.textColor = .gray
       textLabel?.font = .normalMedium
        detailTextLabel?.textColor = .lightGray
      detailTextLabel?.font = .normalSmall
       
    }

    override func update() {
        super.update()
       
        textLabel?.text = row.title // Title
        detailTextLabel?.text = row.value // Subtitle
        textLabel?.textColor = .gray
       textLabel?.font = .normalMedium
        detailTextLabel?.textColor = .lightGray
      detailTextLabel?.font = .normalSmall
    }
}

// Custom Row that Uses the SubtitleCell
final class SubtitleRow: Row<SubtitleCell>, RowType {
    required init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<SubtitleCell>() // Use our custom cell
    }
}
protocol GeneralSettingsDelegate: AnyObject {
    func pushFoldersScreen()
    func pushServerListScreen()
}
