//
//  AddFolderNewViewController.swift
//  Save
//
//  Created by navoda on 2024-12-27.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class AddFolderNewViewController:UIViewController {

    private var doStore = true
    private var project: Project?
    private lazy var ccEnabled = SelectedSpace.space?.license == nil
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
  
    
    @objc func connect() {
           if let spaceId = project?.spaceId,
              let name = folderNameTextField.text {

               let alert = DuplicateFolderAlert(nil)

               if alert.exists(spaceId: spaceId, name: name) {
                   present(alert, animated: true)
                   return
               }
           }
           else {
               return
           }

           project?.name = folderNameTextField.text

           if self.doStore {
               self.store()
           }
        navigationController?.popViewController(animated: true)
          
       }

    // MARK: Private Methods


    func store() {
        if let project {
            Db.writeConn?.setObject(project)
        }
    
    }
   
    let folderNameLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString( "Folder Name",comment:"")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let folderNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder =  NSLocalizedString("Folder Name",comment: "")
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = folderNameTextField.text?.count ?? 0 > 0
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        self.project = Project(space: SelectedSpace.space)
        navigationItem.title = NSLocalizedString( "Create Folder",comment:"")
        folderNameTextField.delegate = self
        folderNameTextField.returnKeyType = .done
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Create", comment: ""), style: .done,
            target: self, action: #selector(connect))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "btDone"
        enableDone()
    }
    
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGray6
        
        // Add subviews
        view.addSubview(folderNameLabel)
        view.addSubview(folderNameTextField)
        
        
        // Constraints for Folder Name Label
        NSLayoutConstraint.activate([
            folderNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            folderNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            folderNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Constraints for Folder Name TextField
        NSLayoutConstraint.activate([
            folderNameTextField.topAnchor.constraint(equalTo: folderNameLabel.bottomAnchor, constant: 8),
            folderNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            folderNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            folderNameTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
      
    }
 
}
extension AddFolderNewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        connect()
        return true
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
           // Get the updated text
           let currentText = textField.text ?? ""
           guard let textRange = Range(range, in: currentText) else { return false }
           let updatedText = currentText.replacingCharacters(in: textRange, with: string)
           
           // Perform any action you want with the updated text
           print("Updated text: \(updatedText)")
           enableDone()
           return true
       }
}
