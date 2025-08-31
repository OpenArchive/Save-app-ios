//
//  QRCodeView.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

class QRCodeViewController: UIViewController {
    private let spaceState: SpaceState

    init(spaceState: SpaceState) {
        self.spaceState = spaceState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Join Space", comment: "")
        let qrView = QRCodeView().environmentObject(spaceState)

        let hosting = UIHostingController(rootView: qrView)
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
}
