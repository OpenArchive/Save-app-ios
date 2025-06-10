//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

class AddNewFolderViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = NSLocalizedString("Create a New Folder", comment: "")
            
            let settingsView = CreateFolderView(disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }, dismissAction: {
                
                if let navigationController = self.navigationController {
                    
                    if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {
                        
                        navigationController.popToViewController(existingVC, animated: true)
                    } else {
                        
                        let newVC = MainViewController()
                        navigationController.pushViewController(newVC, animated: true)
                    }
                }
            })
            
            let hostingController = UIHostingController(rootView: settingsView)
            addChild(hostingController)
            view.addSubview(hostingController.view)
            
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hostingController.didMove(toParent: self)
            self.view.backgroundColor = UIColor.systemBackground
        }
    }
}
