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
        self.title = NSLocalizedString("Internet Archive", comment: "")
        viewModel?.store.listen { [weak self] action in
            switch action {
            case .Next(let space):
                self?.onNext(space)
            case .Cancel:
                self?.onCancel()
            case .isLoginOnprogress:
                self?.navigationItem.hidesBackButton = true
            case .isLoginFinished:
                self?.navigationItem.hidesBackButton = false
            default:
                break
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("InternetArchiveLogin")
    }

    private func onNext(_ space: IaSpace) {
        let vc = UIStoryboard.main.instantiate(CreateCCLViewController.self)
        vc.space = space
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func onCancel() {
        self.navigationController?.popViewController(animated: true)
    }
}
