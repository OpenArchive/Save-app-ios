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

class InternetArchiveLoginViewController : UIHostingController<InternetArchiveLoginView>, WizardDelegatable  {
    
    typealias Action = LoginAction
    
    private var listenScope = StoreScope()
    
    weak var delegate: WizardDelegate?
    
    private var viewModel: InternetArchiveLoginViewModel = Container.shared.internetArchiveViewModel(StoreScope())

    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: InternetArchiveLoginView(viewModel: viewModel))
    }
    
    required init() {
        super.init(rootView: InternetArchiveLoginView(viewModel: viewModel))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.store.listen { action in
            switch action {
            case .LoggedIn:
                self.onLogin()
            case .Cancel:
                self.onCancel()
            default:
                break
            }
        }.store(in: &listenScope)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        viewModel.scope.cancel()
    }
    
    private func onLogin() {
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
        vc.spaceName = IaSpace.defaultPrettyName
        self.delegate?.next(vc, pos: 2)
    }
    
    private func onCancel() {
        self.delegate?.back()
    }
}
