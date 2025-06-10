//
//  ProofModeSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import LibProofMode
import SwiftUI

class ProofModeSettingsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("ProofMode", comment: "")
        
        if #available(iOS 14.0, *) {
            
            let settingsView = ProofModeSettingsView()
            
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
            hostingController.view.backgroundColor = UIColor.systemBackground
            view.backgroundColor = UIColor.systemBackground
        }
    }
}

