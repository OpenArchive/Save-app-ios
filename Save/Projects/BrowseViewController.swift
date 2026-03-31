//
//  BrowseViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class BrowseViewController: UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private var selectedFolder: BrowseFolder?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = NSLocalizedString("Browse Existing", comment: "")

        let browseView = BrowseView(
            onAddFolder: { [weak self] folder in
                self?.addFolder(folder)
            },
            onSelectionChange: { [weak self] folder in
                self?.selectedFolder = folder
                self?.updateNavigationBar()
            }
        )

        let hostingController = UIHostingController(rootView: browseView)
        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationBar()
    }

    private func updateNavigationBar() {
        if selectedFolder != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("ADD", comment: ""),
                style: .done,
                target: self,
                action: #selector(addButtonTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc private func addButtonTapped() {
        guard let folder = selectedFolder else { return }
        addFolder(folder)
    }

    private func addFolder(_ folder: BrowseFolder) {
        guard let space = SelectedSpace.space else { return }

        let exists = DuplicateFolderAlert(nil).exists(spaceId: space.id, name: folder.name)

        if exists {
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Error", comment: ""),
                message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                primaryButtonAction: {},
                showCheckbox: false,
                iconImage: Image("ic_error"),
                iconTint: .gray
            )
            present(alertVC, animated: true)
        } else {
            let project = Project(name: folder.name, space: space)
            Db.writeConn?.setObject(project)
            SelectedProject.project = project
            SelectedProject.store()

            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Success!", comment: ""),
                message: NSLocalizedString("You have added a folder successfully.", comment: ""),
                primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                primaryButtonAction: { [weak self] in
                    self?.popToMainViewController()
                },
                showCheckbox: false,
                iconImage: Image("check_icon")
            )
            present(alertVC, animated: true)
        }
    }

    private func popToMainViewController() {
        guard let navigationController = navigationController else { return }
        if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {
            navigationController.popToViewController(existingVC, animated: true)
        } else {
            navigationController.pushViewController(MainViewController(), animated: true)
        }
    }
}
