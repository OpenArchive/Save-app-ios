//
//  ManageDIDsViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import UIKit
import SwiftUI

class ManageDIDsViewController: UIViewController {
    private let didState: DIDState
    private let spaceDid: String
    
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

    @objc private func addDidTapped() {
        let scanVC = ScanDIDViewController(didState: didState, spaceDid: spaceDid)
           navigationController?.pushViewController(scanVC, animated: true)
    }
}
