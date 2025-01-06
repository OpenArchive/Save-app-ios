//
//  InternetArchiveLoginViewController.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import Factory

class InternetArchiveLoginViewController : ViewModelController<InternetArchiveLoginState, InternetArchiveLoginAction, InternetArchiveLoginViewModel, InternetArchiveLoginView>, WizardDelegatable  {
    
    typealias Action = InternetArchiveLoginAction
    
    weak var delegate: WizardDelegate?
    
    required init() {
        let viewModel = Container.shared.internetArchiveLoginViewModel()
        super.init(
            viewModel: viewModel,
            rootView: InternetArchiveLoginView(viewModel: viewModel)
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
        self.navigationItem.title = NSLocalizedString("Internet Archive" ,comment: "")
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
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
        vc.spaceName = IaSpace.defaultPrettyName
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func onCancel() {
        navigationController?.popViewController(animated: true)
    }
}
