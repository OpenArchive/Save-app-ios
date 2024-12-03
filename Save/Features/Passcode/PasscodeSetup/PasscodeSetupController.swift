//
//  PinCreateController.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit
import Factory

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
        navigationItem.title = NSLocalizedString("Setup Passcode", comment: "")
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
        navigationController?.popViewController(animated: true)
    }
}
