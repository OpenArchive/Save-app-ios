//
//  FolderListViewController.swift
//  Save
//
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class FolderListNewViewController: UIViewController {
    
    private let archived: Bool
    
    init(archived: Bool) {
        self.archived = archived
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        archived = aDecoder.decodeBool(forKey: "archived")
        super.init(coder: aDecoder)
    }

    override func encode(with coder: NSCoder) {
        coder.encode(archived, forKey: "archived")
        super.encode(with: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let folderListView = FolderListView(archived: archived) { [weak self] project in
            self?.navigationController?.pushViewController(EditFolderViewController(project), animated: true)
        }
        
        let hostingController = UIHostingController(rootView: folderListView)
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
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.title = NSLocalizedString("Archived Folders", comment: "")
    }
}
