//
//  VerificationSuccessViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import UIKit
import SwiftUI

class VerificationSuccessViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let view = VerificationSuccessView {
            if let navigationController = self.navigationController {
                
                if let existingVC = navigationController.viewControllers.first(where: { $0 is StorachaSettingViewController }) {
                    
                    navigationController.popToViewController(existingVC, animated: true)
                } else {
                    
                    let newVC = MainViewController()
                    navigationController.pushViewController(newVC, animated: true)
                }
            }
        }
        navigationItem.hidesBackButton = true

        let hostingController = UIHostingController(rootView: view)
        addChild(hostingController)
        self.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}
