//
//  AddFolderViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class AddFolderViewController: UIViewController {

    var noBrowse: Bool {
        SelectedSpace.space is IaSpace
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Add a Folder", comment: "")

        if noBrowse, var stack = navigationController?.viewControllers {
            stack.removeAll { $0 is AddFolderViewController }
            stack.append(AddNewFolderViewController())
            navigationController?.setViewControllers(stack, animated: false)
            return
        }

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        let addFolderView = AddFolderView(
            onCreateNew: { [weak self] in
                self?.navigationController?.pushViewController(AddNewFolderViewController(), animated: true)
            },
            onBrowse: { [weak self] in
                self?.performBrowse()
            }
        )

        let hostingController = UIHostingController(rootView: addFolderView)
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("AddFolder")
    }

    func performBrowse() {
        navigationController?.pushViewController(BrowseViewController(), animated: true)
    }
}
