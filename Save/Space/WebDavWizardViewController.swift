//
//  WebDavWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

final class WebDavWizardViewController: UIHostingController<WebDavWizardView> {

    private let viewModel = WebDavWizardViewModel()

    required init() {
        super.init(rootView: WebDavWizardView(viewModel: viewModel))
        title = NSLocalizedString("Private Server", comment: "")
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        viewModel.onSuccess = { [weak self] space in
            self?.onSuccess(space)
        }
        viewModel.onCancel = { [weak self] in
            self?.onCancel()
        }
        viewModel.onBusyChanged = { [weak self] isBusy in
            self?.navigationItem.hidesBackButton = isBusy
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("PrivateServerLogin")
    }

    private func onSuccess(_ space: WebDavSpace) {
        let vc = CreateCCLHostingController(space: space)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func onCancel() {
        navigationController?.popViewController(animated: true)
    }
}
