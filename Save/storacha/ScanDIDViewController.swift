//
//  ScanDIDViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class ScanDIDViewController: UIViewController {
    private let didState: DIDState
    private let spaceDid: String
    private var cancellables = Set<AnyCancellable>()

    init(didState: DIDState, spaceDid: String) {
        self.didState = didState
        self.spaceDid = spaceDid
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Setup 401 error observers
        setupErrorObservers()
        
        if #available(iOS 14.0, *) {
            let scanView = ScanDIDView(spaceDid: spaceDid)
                .environmentObject(didState)

            let hosting = UIHostingController(rootView: scanView)
            addChild(hosting)
            view.addSubview(hosting.view)
            title = NSLocalizedString("Add DID", comment: "")
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hosting.didMove(toParent: self)
        } else {
            let label = UILabel()
            label.text = "Unsupported iOS version"
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
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
        login()
    }
    private func login() {
        guard let navigationController = navigationController else { return }
        
        if let loginVC = navigationController.viewControllers.first(where: { $0 is StorachaLoginViewController }) {
        
            navigationController.popToViewController(loginVC, animated: true)
        } else if let settingsVC = navigationController.viewControllers.first(where: { $0 is StorachaSettingViewController }) {
        
            let loginVC = StorachaLoginViewController()
            
            if let settingsIndex = navigationController.viewControllers.firstIndex(of: settingsVC) {
              
                var newStack = Array(navigationController.viewControllers[0...settingsIndex])
                newStack.append(loginVC)
                navigationController.setViewControllers(newStack, animated: true)
            } else {
               
                navigationController.pushViewController(loginVC, animated: true)
            }
        } else {
        
            navigationController.popToRootViewController(animated: true)
        }
    }
}
