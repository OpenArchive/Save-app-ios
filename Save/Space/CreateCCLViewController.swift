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
class CreateCCLViewController: FormViewController,TextBoxDelegate {
    
    private var keyboardHandling: KeyboardHandling?
    private let cc = CcSelector(individual: false)
    var space: WebDavSpace?
    var editSpace:Space?
    var isFromCreateServer: Bool = false
    weak var delegate: UpdateNameDelegate?
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
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
        keyboardHandling = KeyboardHandling(scrollView: scrollView,viewController: self)
        setupForm()
        if(!isFromCreateServer){
            nameTab.text = editSpace?.name ?? ""
        }
        titleLbl.text = (isFromCreateServer) ? NSLocalizedString("Tell us little more about your new server", comment: "") : ""
        nextButton.isHidden = !(isFromCreateServer)
        navigationItem.title = (isFromCreateServer) ? NSLocalizedString("Select a License", comment: "")  : NSLocalizedString("Edit Private Server", comment: "")
        hideKeyboardOnOutsideTap()
    }
    
    private func setupForm() {
        self.tableView?.removeFromSuperview()
        formContainer.addSubview(tableView!)

        tableView?.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView?.isScrollEnabled = false
        tableView?.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        
        NSLayoutConstraint.activate([
            tableView!.topAnchor.constraint(equalTo: formContainer.topAnchor),
            tableView!.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor),
            tableView!.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            tableView!.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor)
        ])
        if(!isFromCreateServer){
            cc.set(editSpace?.license, enabled: true)
        }
        form
        +++ Section(""){ section in
            section.header?.height = { TableHeader.minSize }
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
        if(isFromCreateServer){
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
        else{
            guard let space = editSpace else {
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
    }
    
    @IBAction func onNextButtonTap(_ sender: Any) {
       
        guard let space = SelectedSpace.space else {
            return
        }
        updateSpaceName(for: space.id, newName: nameTab.text ?? "")
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
            vc.spaceName = space.prettyName
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
        if(!(isFromCreateServer)){
            delegate?.updateName(nameTab.text ?? "")
            updateSpaceName(for: editSpace?.id ?? "", newName: nameTab.text ?? "")
        }
    }
    
    func textBox(shouldReturn textBox: TextBox) -> Bool {
        dismissKeyboard()
        return true
    }
}
