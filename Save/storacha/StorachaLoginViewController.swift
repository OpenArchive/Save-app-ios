//
//  StorachaLoginViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

import UIKit
import SwiftUI

class StorachaLoginViewController: UIViewController {
    
    private var appState: StorachaAppState!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = NSLocalizedString("Login", comment: "")
            
            appState = StorachaAppState()
            
            // Pass only the auth state into the login view
            let loginView = StorachaLoginView(
                state: appState.authState,
                dispatch: { [weak self] action in
                    self?.handle(action: action)
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
    
    private func handle(action: StorachaLoginAction) {
        switch action {
        case .login:
            Task {
                await appState.authState.login(email: appState.authState.email)
                
                await MainActor.run {
                    if appState.authState.isAuthenticated, let user = appState.authState.currentUser {
                        let vc = VerificationSuccessViewController(appState:appState)
                        navigationController?.pushViewController(vc, animated: true)
                        
                    } else if appState.authState.currentUser != nil {
                        let verificationVC = VerificationSentViewController()
                        verificationVC.configure(
                            with: appState.authState.lastUsedEmail,
                            appState: appState
                        )
                        self.navigationController?.pushViewController(verificationVC, animated: true)
                    } else if let error = appState.authState.error {
                        self.showErrorAlert(message: error.localizedDescription)
                    }
                }
            }
            
        case .createAccount:
            print("create account flow")
            
        case .cancel:
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - Helper Methods
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
