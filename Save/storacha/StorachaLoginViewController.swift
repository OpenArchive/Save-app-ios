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

    private let appState: StorachaAppState

    init(appState: StorachaAppState) {
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.title = NSLocalizedString("Login", comment: "")

        let loginView = StorachaLoginView(
                state: appState.authState,
                onLogin: { [weak self] in self?.handleLogin() },
                onCreateAccount: { [weak self] in self?.handleCreateAccount() },
                onCancel: { [weak self] in self?.navigationController?.popViewController(animated: true) },
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
    
    private func handleLogin() {
        Task {
            await appState.authState.login(email: appState.authState.email)

            await MainActor.run {
                if appState.authState.isAuthenticated, appState.authState.currentUser != nil {
                    let vc = VerificationSuccessViewController(appState: appState)
                    navigationController?.pushViewController(vc, animated: true)
                } else if appState.authState.currentUser != nil {
                    let verificationVC = VerificationSentViewController()
                    verificationVC.configure(
                        with: appState.authState.lastUsedEmail,
                        appState: appState
                    )
                    navigationController?.pushViewController(verificationVC, animated: true)
                } else if let error = appState.authState.error {
                    showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func handleCreateAccount() {
        if let url = URL(string: "https://console.storacha.network/") {
            UIApplication.shared.open(url)
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
