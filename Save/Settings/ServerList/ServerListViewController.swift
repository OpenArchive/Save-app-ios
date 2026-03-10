//
//  ServerListViewController.swift
//  Save
//
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class ServerListViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Media Servers", comment: "")
        
        let serverListView = ServerListView(
            onAddServer: { [weak self] in
                self?.navigationController?.pushViewController(SpaceTypeViewController(), animated: true)
            },
            onSelectSpace: { [weak self] space in
                self?.editServer(space)
            }
        )
        
        let hostingController = UIHostingController(rootView: serverListView)
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
    }
    
    private func editServer(_ space: Space) {
        switch space {
        case let iaSpace as IaSpace:
            navigationController?.pushViewController(InternetArchiveDetailsController(space: iaSpace), animated: true)
        case let webDavSpace as WebDavSpace:
            let vc = PrivateServerSettingViewController()
            vc.space = webDavSpace
            navigationController?.pushViewController(vc, animated: true)
        default:
            #if DEBUG
            print("no navigation")
            #endif
        }
    }
}
