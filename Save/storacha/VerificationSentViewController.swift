//
//  VerificationSentViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class VerificationSentViewController: UIViewController {
    
    private var email: String = ""
    private var appState: StorachaAppState?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let view = VerificationSentView(email: email) {
            self.pushSuccess()
        }

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
    
    // Add the missing configure method
    func configure(with email: String, appState: StorachaAppState) {
        self.email = email
        self.appState = appState
    }

    private func pushSuccess() {
        let vc = VerificationSuccessViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}
