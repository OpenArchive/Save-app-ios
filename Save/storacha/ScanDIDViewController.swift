//
//  ScanDIDViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class ScanDIDViewController: UIViewController {
    private let didState: DIDState
    private let spaceDid: String

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
}
