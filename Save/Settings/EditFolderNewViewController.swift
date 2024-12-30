//
//  EditFolderNewViewController.swift
//  Save
//
//  Created by navoda on 2024-12-27.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit


class EditFolderNewViewController: UIViewController {
  
    var project: Project
    init(_ project: Project) {
        self.project = project
        super.init(nibName: nil, bundle: nil) // Call designated initializer
    }

    // Required initializer for NSCoder (if using storyboards or archiving)
    required init?(coder decoder: NSCoder) {
        // Provide a default or decode the project if applicable
        guard let decodedProject = decoder.decodeObject(forKey: "project") as? Project else {
            return nil
        }
        self.project = decodedProject
        super.init(coder: decoder)
    }

    private var archiveLabel: String {
        return project.active ? NSLocalizedString("Archive Folder", comment: "") : NSLocalizedString("Unarchive Folder", comment: "")
    }

    /**
     Store, as long as this is set to true.
     Workaround for issue #122: Project gets deleted, but re-added when scene is
     left, due to various #store calls which get triggered.
    */
    private var doStore = true

    private lazy var ccEnabled = SelectedSpace.space?.license == nil
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }



 func connect() {
        if let spaceId = project.spaceId,
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

        project.name = folderNameTextField.text
        self.navigationItem.title = self.project.name

        if self.doStore {
            self.store()
        }

       
    }


    // MARK: Private Methods

    func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = folderNameTextField.text?.count ?? 0 > 0
    }

    func store() {
        Db.writeConn?.setObject(project)
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
        textField.placeholder = NSLocalizedString( "Folder Name",comment:"")
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    let removeButton: UIButton = {
        let button = UIButton()
      
        button.setTitle(NSLocalizedString( "Remove from App",comment:""), for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        button.setImage(UIImage(systemName: "trash"), for: .normal)
        button.tintColor = .red
        button.contentHorizontalAlignment = .left
   
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let archiveButton: UIButton = {
        let button = UIButton()

        button.setTitle("", for: .normal)
        button.setTitleColor(.darkGray, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.contentHorizontalAlignment = .right
    
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        archiveButton.setTitle(archiveLabel,for: .normal)
        folderNameTextField.text = project.name
        navigationItem.title = project.name
        folderNameTextField.delegate = self
        folderNameTextField.returnKeyType = .done
        enableDone()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGray6
        
        // Add subviews
        view.addSubview(folderNameLabel)
        view.addSubview(folderNameTextField)
        view.addSubview(removeButton)
        view.addSubview(archiveButton)
        
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
        
        // Constraints for Remove Button
        NSLayoutConstraint.activate([
            removeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            removeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        // Constraints for Archive Button
        NSLayoutConstraint.activate([
            archiveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            archiveButton.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor)
        ])
    }
    private func setupActions() {
            removeButton.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
            archiveButton.addTarget(self, action: #selector(archiveButtonTapped), for: .touchUpInside)
        }
        
        // MARK: - Button Actions
        
        @objc private func removeButtonTapped() {
            RemoveProjectAlert.present(self, self.project, { [weak self] success in
                guard success else {
                    return
                }

                self?.doStore = false
                self?.navigationController?.popViewController(animated: true)
            })
        }
        
        @objc private func archiveButtonTapped() {
            self.project.active = !(self.project.active)

            if self.project.active, let license = SelectedSpace.space?.license {
                self.project.license = license
            }

            if self.doStore {
                self.store()
            }

            archiveButton.setTitle(archiveLabel, for: .normal)
         
        }
   
}
extension EditFolderNewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        connect() 
        return true
    }
}
