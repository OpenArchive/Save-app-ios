//
//  PrivateServerSettingViewController.swift
//  Save
//
//  Created by navoda on 2025-02-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//
import UIKit
import SwiftUI

import UIKit
import SwiftUI

class PrivateServerSettingViewController: UIViewController {
    var space: Space?
    private lazy var confirmItem: UIBarButtonItem = {
            UIBarButtonItem(title: NSLocalizedString("Confirm", comment: ""),
                            style: .done,
                            target: self,
                            action: #selector(confirmTapped))
        }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = space?.prettyName ?? WebDavSpace.defaultPrettyName
            if let space = space {
                let settingsView = PrivateServerSettingsView(space: space, disableBackAction: { [weak self] isDisabled in
                    self?.navigationItem.hidesBackButton = isDisabled
                },  dismissAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
                , changeTitle: { [weak self] titleValue in
                    
                    self?.title = titleValue
                }, onEditingChanged: { [weak self] isEditing in
                    guard let self else { return }
                    self.navigationItem.rightBarButtonItem = isEditing ? self.confirmItem : nil
                })
                
                let hostingController = UIHostingController(rootView: settingsView)
                
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
                hostingController.view.backgroundColor = .clear
                view.backgroundColor = .clear
            }
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trackScreenViewSafely("PrivateServerDetails")
    }
    
    @objc private func confirmTapped() {
        view.endEditing(true)
        NotificationCenter.default.post(
            name: Foundation.Notification.Name.privateServerSettingsConfirm,
            object: space?.id
        )
    }
}
