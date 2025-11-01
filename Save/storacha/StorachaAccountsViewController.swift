//
//  StorachaAccountsViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class StorachaAccountsViewController: UIViewController {
    private let appState: StorachaAppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: StorachaAppState) {
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appState.restoreSession()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Accounts"
        view.backgroundColor = .systemBackground
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        // Setup 401 error observers
        setupErrorObservers()
        
        let contentView = AccountListView(
            onSelect: { [weak self] email in
                self?.navigateToDetail(email: email)
            }
        ).environmentObject(appState)

        let hosting = UIHostingController(rootView: contentView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - 401 Error Handling
    private func setupErrorObservers() {
        // Observe error changes in appState
        appState.$error
            .sink { [weak self] error in
                if let apiError = error, case .unauthorized = apiError {
                    self?.showUnauthorizedAlert()
                }
            }
            .store(in: &cancellables)
    }
    
    private func showUnauthorizedAlert() {

        let alertVC = CustomAlertViewController(
              title: NSLocalizedString("Session Expired", comment: ""),
              message: NSLocalizedString("Your session has expired. Please login again to continue." , comment: ""),
              primaryButtonTitle: NSLocalizedString("Back to Login", comment: ""),
              primaryButtonAction: { [weak self] in
                  self?.handleLogout()
              },
              iconImage: Image(systemName: "exclamationmark.triangle.fill"),
              iconTint: .accent
          )
          
          present(alertVC, animated: true)
    }
    
    private func handleLogout() {
        // Clear session and accounts
        appState.clearAccounts()
        appState.authState.logout()
        appState.clearError()
        
        // Navigate to login
        navigateToLogin()
    }
    
    private func navigateToLogin() {
        guard let navigationController = navigationController else { return }
        
        // Try to find StorachaLoginViewController in the stack
        if let loginVC = navigationController.viewControllers.first(where: { $0 is StorachaLoginViewController }) {
            // Pop back to existing login controller
            navigationController.popToViewController(loginVC, animated: true)
        } else {
            // Create and navigate to new login controller
            let loginVC = StorachaLoginViewController()
            navigationController.setViewControllers([loginVC], animated: true)
        }
    }

    private func navigateToDetail(email: String) {
        let detailView = AccountDetailView(email: email) { [weak self] in
            self?.handleLogout()
        }.environmentObject(appState)
        
        let hosting = UIHostingController(rootView: detailView)
        hosting.title = NSLocalizedString("Accounts", comment: "")
        navigationController?.pushViewController(hosting, animated: true)
    }
}
