//
//  AddFolderNewViewController.swift
//  Save
//
//  Created by navoda on 2024-12-27.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class AddFolderNewViewController:BaseFolderViewControllerNew {
    
    // MARK: - Properties
    let folderNameLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString( "Folder Name",comment:"")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        navigationItem.title = NSLocalizedString( "Create Folder",comment:"")
        folderNameTextField.delegate = self
        folderNameTextField.returnKeyType = .done
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Create", comment: ""), style: .done,
            target: self, action: #selector(create))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "btDone"
        
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(dismissController))
        navigationItem.leftBarButtonItem = backButton
        enableDone()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    @objc private func dismissController() {
        navigationController?.popViewController(animated: true)
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
    // MARK: - Helper Methods
    @objc func create() {
        connect()
        dismissController()
    }
}
extension AddFolderNewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        connect()
        navigationController?.popViewController(animated: true)
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
