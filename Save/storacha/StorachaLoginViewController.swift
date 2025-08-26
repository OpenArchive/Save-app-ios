//
//  StorachaLoginViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

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
    
    private var appState: StorachaAppState!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = ""
            
            // Create the app state as an instance property
            appState = StorachaAppState()
            
            let loginView = StorachaLoginView(
                state: appState,
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
                // Call login with the email from the state
                await appState.login(email: appState.email)
                
                await MainActor.run {
                    if appState.isAuthenticated && appState.currentUser != nil {
                        let accountsVC = StorachaAccountsviewController()
                        self.navigationController?.pushViewController(accountsVC, animated: true)
                    } else if appState.currentUser != nil {
                        let verificationVC = VerificationSentViewController()
                        verificationVC.configure(with: appState.lastUsedEmail, appState: appState)
                        self.navigationController?.pushViewController(verificationVC, animated: true)
                    }
                }
            }
        case .createAccount:
            print("create account")
        case .cancel:
            navigationController?.popViewController(animated: true)
        }
    }
}
