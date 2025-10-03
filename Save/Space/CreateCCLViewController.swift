//
//  CreateCCLViewController.swift
//  Save
//
//  Created by navoda on 2024-11-16.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import YapDatabase
class CreateCCLViewController: FormViewController, WizardDelegatable,TextBoxDelegate {
    
    @IBOutlet weak var labelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var nameTabHeight: NSLayoutConstraint!
    private var keyboardHandling: KeyboardHandling?
    private let cc = CcSelector(individual: false)
    var delegate: WizardDelegate?
    var space: Space?
    @IBOutlet weak var nameTab: TextBox!{
        
            didSet {
                nameTab.textField.font = .montserrat(forTextStyle: .footnote)
                nameTab.placeholder = NSLocalizedString("Server Name (Optional)", comment: "")
                nameTab.delegate = self
                nameTab.autocorrectionType = .no
                nameTab.autocapitalizationType = .none
                nameTab.textField.returnKeyType = .next
                nameTab.textField.textColor = .gray70
        }
    }
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLbl: UILabel!
    @IBOutlet weak var nextButton: UIButton!{
        didSet{
            nextButton.cornerRadius = 10
        }
    }
    @IBOutlet weak var formContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardHandling = KeyboardHandling(scrollView: scrollView,viewController: self)
        self.navigationItem.hidesBackButton = true
        if(space is IaSpace){
            titleLbl.text = NSLocalizedString("Choose a licence", comment: "")
            labelBottomConstraint.constant = 0
            nameTab.isHidden = true
            nameTabHeight.constant = 0
            self.title = NSLocalizedString("Internet Archive", comment: "")
        }else{
            labelBottomConstraint.constant = 50
            nameTab.isHidden = false
            nameTabHeight.constant = 50
            self.title = NSLocalizedString("Private Server", comment: "")
        }
        
        setupForm()
        hideKeyboardOnOutsideTap()
    }
    
    private func setupForm() {
        
        self.tableView?.removeFromSuperview()
        formContainer.addSubview(tableView!)
        
        // Constrain the form's tableView to fill the `formContainerView`
        tableView?.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView?.isScrollEnabled = false
        tableView?.showsVerticalScrollIndicator = false
        tableView.rowHeight = 53
        
        
        NSLayoutConstraint.activate([
            tableView!.topAnchor.constraint(equalTo: formContainer.topAnchor),
            tableView!.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor),
            tableView!.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            tableView!.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor)
        ])
        
        // Define form sections and rows
        form
        +++ Section(""){ section in
            section.header?.height = { TableHeader.minSize }         }
        
        <<< cc.ccSw.onChange { [weak self] row in
            self?.ccLicenseChanged(row)
        }
        <<< cc.cc0Sw.onChange { [weak self] row in
            self?.cc0LicenseChanged(row)
        }
        <<< cc.remixSw.onChange { [weak self] row in
            print("change remix")
            self?.otherLicenseChanged(row)
        }
        
        <<< cc.shareAlikeSw.onChange { [weak self] row in
            self?.otherLicenseChanged(row)
        }
        
        <<< cc.commercialSw.onChange { [weak self] row in
            self?.otherLicenseChanged(row)
        }
        <<< LabelRow() { row in
            row.title = " "
            row.cell.backgroundColor = .clear
            row.cell.height = { 10 }
        }
        <<< cc.licenseRow
        
        <<< cc.learnMoreRow
    }
    
    private func hideKeyboardOnOutsideTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    /**
     Hides the soft keyboard, if one is shown.
     */
    @objc public func dismissKeyboard() {
        view.endEditing(true)
    }
    private func ccLicenseChanged(_ row: SwitchRow) {
        guard let space = SelectedSpace.space else {
            _ = cc.get()
            
            return
        }
        
        space.license = cc.get()
        
        Db.writeConn?.asyncReadWrite { tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)
            
            let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }
            
            for project in projects {
                project.license = space.license
                
                tx.setObject(project)
            }
        }
    }
    private func cc0LicenseChanged(_ row: SwitchRow) {
        if !cc.isUpdatingValues {
            cc.handleCC0Toggle()
        }
        ccLicenseChanged(row)
    }
    
    private func otherLicenseChanged(_ row: SwitchRow) {
        if !cc.isUpdatingValues {
            cc.handleOtherToggle()
        }
        ccLicenseChanged(row)
    }
    
    @IBAction func onNextButtonTap(_ sender: Any) {
        guard let space = SelectedSpace.space else {
            return
        }
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
        if(space is IaSpace){
            vc.spaceName = NSLocalizedString("the Internet Archive", comment: "")
        }else{
            updateSpaceName(for: space.id, newName: nameTab.text ?? "")
            vc.spaceName = NSLocalizedString("a private server", comment: "")
        }
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func updateSpaceName(for spaceId: String, newName: String) {
        Db.writeConn?.asyncReadWrite { tx in
            
            if let space = tx.object(forKey: spaceId, inCollection: Space.collection) as? Space {
                
                space.name = newName
                tx.setObject(space, forKey: space.id, inCollection: Space.collection)
                if SelectedSpace.id == spaceId {
                    SelectedSpace.space?.name = space.name
                    
                }
            }
        }
    }
    // MARK: TextBoxDelegate
    
    func textBox(didUpdate textBox: TextBox) {
        
    }
    
    func textBox(shouldReturn textBox: TextBox) -> Bool {
        dismissKeyboard()
        return true
    }
}
