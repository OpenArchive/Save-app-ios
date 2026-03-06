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

    var storachaAppState: StorachaAppState { appState }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
  
            navigationItem.title = NSLocalizedString("Storacha", comment: "")
        
            appState = StorachaAppState()

            let settingsView = StorachaSettingView(
                appState: appState,
                disableBackAction: { [weak self] isDisabled in
                    self?.navigationItem.hidesBackButton = isDisabled
                },
                dismissAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                },
                manageAccountsAction: { [weak self] action in
                    switch action {
                    case .manageAccounts:
                        self?.handleManageNavigation()
                    case .joinSpace:
                        self?.manageSpaceNavigation(isNew: true)
                    case .mySpaces:
                        self?.manageSpaceNavigation(isNew: false)
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appState.refreshSpaceCountAndSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        let loginVC = StorachaLoginViewController(appState: appState)
        navigationController?.pushViewController(loginVC, animated: true)
    }
    
    private func navigateToAccountDetails(email: String) {
        let newVC = StorachaAccountsViewController(appState: appState)
        self.navigationController?.pushViewController(newVC, animated:true)
    }
    
    func manageSpaceNavigation(isNew: Bool) {
        if(isNew){
            let newVC = QRCodeViewController(appStateval: self.appState)
            self.navigationController?.pushViewController(newVC, animated: true)
        } else{
            let newVC = SpaceListViewController(appState:  self.appState)
            self.navigationController?.pushViewController(newVC, animated: true)
        }
      
    }
}
