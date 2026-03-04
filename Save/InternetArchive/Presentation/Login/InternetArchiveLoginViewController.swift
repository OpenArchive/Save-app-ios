//
//  InternetArchiveLoginViewController.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import FactoryKit

class InternetArchiveLoginViewController: UIHostingController<InternetArchiveLoginView>, WizardDelegatable {

    weak var delegate: WizardDelegate?

    private let viewModel: InternetArchiveLoginViewModel

    required init() {
        viewModel = Container.shared.internetArchiveLoginViewModel()
        super.init(rootView: InternetArchiveLoginView(viewModel: viewModel))
        title = NSLocalizedString("Internet Archive", comment: "")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.onNext = { [weak self] space in
            self?.onNext(space)
        }
        viewModel.onCancel = { [weak self] in
            self?.onCancel()
        }
        viewModel.onLoginProgress = { [weak self] inProgress in
            self?.navigationItem.hidesBackButton = inProgress
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("InternetArchiveLogin")
    }

    private func onNext(_ space: IaSpace) {
        let vc = CreateCCLWrapperViewController()
        vc.space = space
        navigationController?.pushViewController(vc, animated: true)
    }

    private func onCancel() {
        navigationController?.popViewController(animated: true)
    }
}
