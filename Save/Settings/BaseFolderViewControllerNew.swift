//
//  BaseFolderViewControllerNew.swift
//  Save
//
//  Created by navoda on 2025-01-06.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
class BaseFolderViewControllerNew:UIViewController{
    
     var project: Project
     var doStore = true // Workaround for issue #122
     let folderNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = NSLocalizedString("Folder Name", comment: "")
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    // MARK: - Initializers

    init(_ project: Project) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder decoder: NSCoder) {
        guard let decodedProject = decoder.decodeObject(forKey: "project") as? Project else {
            return nil
        }
        self.project = decodedProject
        super.init(coder: decoder)
    }

    func connect() {
        guard let spaceId = project.spaceId, let name = folderNameTextField.text else { return }

        let alert = DuplicateFolderAlert(nil)
        if alert.exists(spaceId: spaceId, name: name) {
            present(alert, animated: true)
            return
        }

        project.name = folderNameTextField.text
        navigationItem.title = project.name
        if doStore {
            store()
        }
    }

    func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = !(folderNameTextField.text?.isEmpty ?? true)
    }

    func store() {
        Db.writeConn?.setObject(project)
    }
}
