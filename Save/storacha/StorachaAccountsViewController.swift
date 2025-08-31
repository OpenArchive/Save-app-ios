//
//  StorachaAccountsViewController 2.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class StorachaAccountsViewController: UIViewController {
    private let appState: StorachaAppState

    init(appState: StorachaAppState) {
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Accounts"
        view.backgroundColor = .systemBackground
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
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

    private func navigateToDetail(email: String) {
        let detailView = AccountDetailView(email: email) { [weak self] in
            self?.appState.clearAccounts()
            self?.appState.authState.logout()
            if let existingVC = self?.navigationController?.viewControllers.first(where: { $0 is StorachaSettingViewController }) {
                self?.navigationController?.popToViewController(existingVC, animated: true)
            } else {
                let newVC = StorachaSettingViewController()
                self?.navigationController?.pushViewController(newVC, animated: true)
            }
        }.environmentObject(appState)
        let hosting = UIHostingController(rootView: detailView)
        hosting.title = "Account"
        navigationController?.pushViewController(hosting, animated: true)
    }
}
