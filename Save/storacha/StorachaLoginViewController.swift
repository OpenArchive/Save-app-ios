//
//  StorachaLoginViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class StorachaLoginViewController: UIViewController {
   

    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        if #available(iOS 14.0, *) {
            navigationItem.title = ""

            let state = StorachaLoginState()

            let loginView = StorachaLoginView(
                state: state,
                dispatch: { [weak self] action in
                    self?.handle(action: action, state: state)
                },
                disableBackAction: { [weak self] isDisabled in
                    self?.navigationItem.hidesBackButton = isDisabled
                },
                dismissAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            )

            let hostingController = UIHostingController(rootView: loginView)
            
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
    private func handle(action: StorachaLoginAction, state: StorachaLoginState) {
        switch action {
        case .login:
            print("Login tapped with email: \(state.email)")
            var stored = UserDefaults.standard.stringArray(forKey: "storedAccounts") ?? []
                   if !stored.contains(state.email) {
                       stored.append(state.email)
                       UserDefaults.standard.setValue(stored, forKey: "storedAccounts")
                   }
            navigationController?.pushViewController(VerificationSentViewController(), animated: true)
        case .cancel:
            navigationController?.popViewController(animated: true)
        case .createAccount:
            // TODO: Navigate to a create account screen
            print("Create Account tapped")
        }
    }

}

