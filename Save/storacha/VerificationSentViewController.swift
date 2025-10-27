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
    private var hostingController: UIHostingController<VerificationSentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        navigationItem.hidesBackButton = true
        navigationItem.title = NSLocalizedString("Email Verification", comment: "")
        
        setupVerificationView()
    }
    
    private func setupVerificationView() {
        guard let authState = appState?.authState else { return }
        
        let verificationView = VerificationSentView(
            authState: authState,
            email: email,
            onVerified: { [weak self] in
                self?.handleVerificationSuccess()
            },
            onTimeout: { [weak self] in
                self?.handleVerificationTimeout()
            }
        )

        let hostingController = UIHostingController(rootView: verificationView)
        self.hostingController = hostingController
        
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
    }
    
    // Configure with AuthState instead of full AppState
    func configure(with email: String, appState: StorachaAppState) {
        self.email = email
        self.appState = appState

        if isViewLoaded {
            setupVerificationView()
        }
    }

    private func handleVerificationSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.pushToSuccess()
        }
    }
    
    private func handleVerificationTimeout() {
        DispatchQueue.main.async { [weak self] in
            self?.showTimeoutAlert()
        }
    }
    
    private func pushToSuccess() {
        if let state = appState {
            let vc = VerificationSuccessViewController(appState:state)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func showTimeoutAlert() {
 
        let alertVC = CustomAlertViewController(
            title: NSLocalizedString("Verification Timeout", comment: ""),
            message: NSLocalizedString("We didn't receive confirmation of your email verification. Please check your email and try again, or return to login.", comment: ""),
            primaryButtonTitle: NSLocalizedString("Try Again", comment: ""),
            primaryButtonAction: {
                self.setupVerificationView()
            },
            secondaryButtonTitle:NSLocalizedString("Back to Login", comment: ""),
            secondaryButtonAction: {
                self.navigationController?.popViewController(animated: true)
            },
            showCheckbox: false,
            iconImage: Image(systemName: "exclamationmark.triangle.fill"),
            iconTint: .accent
        )
        self.present(alertVC, animated: true)
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appState?.authState.stopVerificationPolling()
    }
}
