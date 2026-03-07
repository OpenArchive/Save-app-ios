//
//  TesterEmailAlertViewController.swift
//  Save
//
//  Created by navoda on 2026-03-07.
//  Copyright © 2026 Open Archive. All rights reserved.
//


//
//  TesterEmailAlertViewController.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

/// Presents the tester email dialog in the same style as CustomAlertViewController.
final class TesterEmailAlertViewController: UIViewController {

    private let onContinue: (String) -> Void
    private let onSkip: () -> Void

    init(onContinue: @escaping (String) -> Void, onSkip: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onSkip = onSkip
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)

        let dialogView = TesterEmailDialogView(
            onContinue: { [weak self] email in
                self?.dismiss(animated: true)
                self?.onContinue(email)
            },
            onSkip: { [weak self] in
                self?.dismiss(animated: true)
                self?.onSkip()
            }
        )
        let hosting = UIHostingController(rootView: dialogView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hosting.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hosting.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        ])
    }
}
