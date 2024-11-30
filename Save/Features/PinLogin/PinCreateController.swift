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

class PinCreateController : ViewModelController<PinCreateState, PinCreateAction, PinCreateViewModel, PinCreateView>{
    
    typealias Action = PinCreateAction
    
    
    required init() {
        let viewModel = Container.shared.pinCreateViewModel()
        super.init(
            viewModel: viewModel,
            rootView: PinCreateView(viewModel: viewModel)
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
            case .Next:
                self?.onNext()
            case .Cancel:
                self?.onCancel()
            default:
                break
            }
        }
    }
    
    private func onNext() {
        navigationController?.popViewController(animated: true)
    }
    
    private func onCancel() {
        navigationController?.popViewController(animated: true)
    }
}
