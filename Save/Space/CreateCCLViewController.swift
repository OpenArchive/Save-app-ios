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
    
    private var keyboardHandling: KeyboardHandling?
    private let cc = CcSelector(individual: false)
    var delegate: WizardDelegate?
    var space: WebDavSpace?
    @IBOutlet weak var nameTab: TextBox!{
        didSet {
            nameTab.placeholder = NSLocalizedString("Server Name (Optional)", comment: "")
            nameTab.delegate = self
            nameTab.autocorrectionType = .no
            nameTab.autocapitalizationType = .none
            nameTab.textField.returnKeyType = .next
            
        }
    }
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLbl: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var formContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardHandling = KeyboardHandling(scrollView: scrollView,viewController: self)
        setupForm()
        hideKeyboardOnOutsideTap()
    }
    
    private func setupForm() {
        // Remove the form's default tableView and add it as a subview to `formContainerView`
        self.tableView?.removeFromSuperview()
        formContainer.addSubview(tableView!)
        
        // Constrain the form's tableView to fill the `formContainerView`
        tableView?.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .white
        tableView?.isScrollEnabled = false
        tableView?.showsVerticalScrollIndicator = false
        
        
        NSLayoutConstraint.activate([
            tableView!.topAnchor.constraint(equalTo: formContainer.topAnchor),
            tableView!.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor),
            tableView!.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            tableView!.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor)
        ])
        
        // Define form sections and rows
        form
        +++ Section(""){ section in
            section.header?.height = { TableHeader.minSize } // Reduce header height to 1 point
        }
        
        <<< cc.ccSw.onChange { [weak self] row in
            self?.ccLicenseChanged(row)
        }
        
        <<< cc.remixSw.onChange { [weak self] row in
            self?.ccLicenseChanged(row)
        }
        
        <<< cc.shareAlikeSw.onChange { [weak self] row in
            self?.ccLicenseChanged(row)
        }
        
        <<< cc.commercialSw.onChange { [weak self] row in
            self?.ccLicenseChanged(row)
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
    
    @IBAction func onNextButtonTap(_ sender: Any) {
        guard let space = SelectedSpace.space else {
            return
        }
        updateSpaceName(for: space.id, newName: nameTab.text ?? "")
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
            vc.spaceName = space.prettyName
            self.delegate?.next(vc, pos: 3)
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
