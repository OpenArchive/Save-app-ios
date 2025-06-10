//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

class NewEditFolderViewController: UIViewController {
    var project: Project
    
    // MARK: - Initializers
    
    init(_ project: Project) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = project.name
            
            
            let editFolderView = EditFolderView(project: project,disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }, dismissAction: {
                
                self.navigationController?.popViewController(animated: true)
            },changeName: { [weak self] name in
                self?.title = name
            })
            
            let hostingController = UIHostingController(rootView: editFolderView)
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
            self.view.backgroundColor = .systemBackground
        }
    }
}
