//
//  PinCreateController.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import FactoryKit

class PasscodeSetupController: UIHostingController<PasscodeSetupView> {

    private let viewModel = Container.shared.passcodeSetupViewModel()

    required init() {
        super.init(rootView: PasscodeSetupView(viewModel: viewModel))
        navigationItem.title = NSLocalizedString("Lock app with passcode", comment: "")
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.onComplete = { [weak self] success in
            if success {
                trackFeatureToggled(featureName: "passcode_protection", enabled: true)
            }
            self?.navigationController?.popViewController(animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("PasscodeSetup")
    }
}
