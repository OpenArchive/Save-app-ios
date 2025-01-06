//
//  EditFolderNewViewController.swift
//  Save
//
//  Created by navoda on 2024-12-27.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class EditFolderNewViewController: BaseFolderViewControllerNew {

    // MARK: - Properties

    private lazy var ccEnabled = SelectedSpace.space?.license == nil

    private var archiveLabel: String {
        return project.active
            ? NSLocalizedString("Archive Folder", comment: "")
            : NSLocalizedString("Unarchive Folder", comment: "")
    }

    // MARK: - UI Elements

    private let folderNameLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Folder Name", comment: "")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()



    private let removeButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Remove from App", comment: ""), for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        button.setImage(UIImage(systemName: "trash"), for: .normal)
        button.tintColor = .red
        button.contentHorizontalAlignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let archiveButton: UIButton = {
        let button = UIButton()
        button.setTitle("", for: .normal)
        button.setTitleColor(.darkGray, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.contentHorizontalAlignment = .right
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()


    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        archiveButton.setTitle(archiveLabel, for: .normal)
        folderNameTextField.text = project.name
        navigationItem.title = project.name
        folderNameTextField.delegate = self
        folderNameTextField.returnKeyType = .done
        enableDone()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemGray6

        // Add subviews
        view.addSubview(folderNameLabel)
        view.addSubview(folderNameTextField)
        view.addSubview(removeButton)
        view.addSubview(archiveButton)

        // Add constraints
        NSLayoutConstraint.activate([
            folderNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            folderNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            folderNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            folderNameTextField.topAnchor.constraint(equalTo: folderNameLabel.bottomAnchor, constant: 8),
            folderNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            folderNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            folderNameTextField.heightAnchor.constraint(equalToConstant: 44),

            removeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            removeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            archiveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            archiveButton.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor)
        ])
    }

    

    // MARK: - Actions

    private func setupActions() {
        removeButton.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
        archiveButton.addTarget(self, action: #selector(archiveButtonTapped), for: .touchUpInside)
    }
    
    @objc private func removeButtonTapped() {
        RemoveProjectAlert.present(self, project) { [weak self] success in
            guard success else { return }
            self?.doStore = false
            self?.navigationController?.popViewController(animated: true)
        }
    }

    @objc private func archiveButtonTapped() {
        project.active.toggle()
        if project.active, let license = SelectedSpace.space?.license {
            project.license = license
        }
        if doStore {
            store()
        }
        archiveButton.setTitle(archiveLabel, for: .normal)
    }


}

// MARK: - UITextFieldDelegate

extension EditFolderNewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        connect()
        return true
    }
}
