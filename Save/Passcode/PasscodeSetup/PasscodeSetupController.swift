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

class PasscodeSetupController : ViewModelController<PasscodeSetupState, PasscodeSetupAction, PasscodeSetupViewModel, PasscodeSetupView>{
    
    typealias Action = PasscodeSetupAction
    
    
    required init() {
        let viewModel = Container.shared.passcodeSetupViewModel()
        super.init(
            viewModel: viewModel,
            rootView: PasscodeSetupView(
                viewModel: viewModel
            )
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Lock app with passcode", comment: "")
        viewModel?.store.listen { [weak self] action in
            switch action {
            case .OnComplete:
                self?.onComplete()
            default:
                break
            }
        }
    }
    
    private func onNext() {
        navigationController?.popViewController(animated: true)
    }
    
    private func onComplete() {
        trackFeatureToggled(featureName: "passcode_protection", enabled: true)
        navigationController?.popViewController(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("PasscodeSetup")
    }
}
