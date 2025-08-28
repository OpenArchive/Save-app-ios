//
//  StorachaSettingViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import UIKit
import SwiftUI

class StorachaSettingViewController: UIViewController {
    
    private var appState: StorachaAppState!
   
    private lazy var storachaLoginViewController: StorachaLoginViewController = {
        let vc = StorachaLoginViewController()
        return vc
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        if #available(iOS 14.0, *) {
            navigationItem.title = ""
            
            // Create app state
            appState = StorachaAppState()

            let settingsView = StorachaSettingView(
                appState: appState,
                disableBackAction: { [weak self] isDisabled in
                    self?.navigationItem.hidesBackButton = isDisabled
                },
                dismissAction: {
                    self.navigationController?.popViewController(animated: true)
                },
                manageAccountsAction: { type in
                    if type == "manage" {
                        self.handleManageNavigation()
                    } else if type == "join" {
                        self.manageSpaceNavigation(isNew: true)
                    } else {
                        self.manageSpaceNavigation(isNew: false)
                    }
                }
            )

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
            hostingController.view.backgroundColor = .clear
            view.backgroundColor = .clear
        }
    }
    
    func handleManageNavigation() {
        Task {
            let result = await appState.checkSessionAndNavigate()
            
            await MainActor.run {
                if result.shouldGoToLogin {
                    self.navigateToLogin()
                } else if result.isVerified {
                    self.navigateToAccountDetails(email: result.userEmail ?? "")
                } else{
                    let verificationVC = VerificationSentViewController()
                    verificationVC.configure(with: result.userEmail ?? "", appState: appState)
                    self.navigationController?.pushViewController(verificationVC, animated: true)
                }
            }
        }
    }
    
    private func navigateToLogin() {
        let loginVC = StorachaLoginViewController()
        self.navigationController?.pushViewController(loginVC, animated: true)
    }
    
    private func navigateToAccountDetails(email: String) {
        let detailView = AccountDetailView(email: email) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        let hosting = UIHostingController(rootView: detailView)
        hosting.title = "Account"
        navigationController?.pushViewController(hosting, animated: true)
    }
    
    func manageSpaceNavigation(isNew: Bool) {
        // TODO: Implement space navigation when needed
    }
}
