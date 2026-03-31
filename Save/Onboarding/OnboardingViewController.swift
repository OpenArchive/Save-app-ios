//
//  OnboardingViewController.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

final class OnboardingViewController: UIHostingController<OnboardingView> {

    required init() {
        super.init(rootView: OnboardingView(onComplete: { _ in }))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView = OnboardingView(onComplete: { [weak self] enableTor in
            self?.complete(enableTor: enableTor)
        })
    }

    private func complete(enableTor: Bool) {
        Settings.firstRunDone = true

        if let navC = navigationController as? MainNavigationController {
            navC.setRoot()
        }
    }
}
