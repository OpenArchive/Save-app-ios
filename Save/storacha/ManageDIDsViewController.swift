//
//  ManageDIDsViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class ManageDIDsViewController: UIViewController {
    private let didState: DIDState
    private let spaceDid: String
    private var cancellables = Set<AnyCancellable>()
    
    init(didState: DIDState, spaceDid: String) {
        self.didState = didState
        self.spaceDid = spaceDid
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Manage Access", comment: "")
        view.backgroundColor = .systemBackground
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("ADD", comment: ""),
            style: .plain,
            target: self,
            action: #selector(addDidTapped)
        )

        // Setup 401 error observers
        setupErrorObservers()

        let contentView = ManageDIDsView(
            didState: didState, spaceDid: spaceDid,
            disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }
        )

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
        // Observe unauthorized alert
        didState.$showUnauthorizedAlert
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.showUnauthorizedAlert()
                }
            }
            .store(in: &cancellables)
        
        // Observe navigation to login
        didState.$shouldNavigateToLogin
            .sink { [weak self] shouldNavigate in
                if shouldNavigate {
                    self?.navigateToLogin()
                }
            }
            .store(in: &cancellables)
    }
    
    private func showUnauthorizedAlert() {
        let message = didState.unauthorizedMessage
        
        let alert = UIAlertController(
            title: "Session Expired",
            message: message,
            preferredStyle: .alert
        )
        
        // Only "Back to Login" button (no "Stay Here" for admin operations)
        alert.addAction(UIAlertAction(title: "Back to Login", style: .default) { [weak self] _ in
            self?.didState.handleBackToLoginAction()
        })
        
        present(alert, animated: true)
    }
    
    private func navigateToLogin() {
        // Reset navigation state
        didState.resetNavigationState()
        
        if let navigationController = navigationController {
           
            if let loginVC = navigationController.viewControllers.first(where: { $0 is StorachaLoginViewController }) {

                navigationController.popToViewController(loginVC, animated: true)
            } else {
            
                let loginVC = StorachaLoginViewController()
                navigationController.pushViewController(loginVC, animated: true)
            }
        }
    }

    @objc private func addDidTapped() {
        let scanVC = ScanDIDViewController(didState: didState, spaceDid: spaceDid)
        navigationController?.pushViewController(scanVC, animated: true)
    }
}
