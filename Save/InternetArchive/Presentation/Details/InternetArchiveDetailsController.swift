//
//  InternetArchiveDetailsController.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import FactoryKit

class InternetArchiveDetailsController: UIHostingController<InternetArchiveDetailView> {

    private let viewModel: InternetArchiveDetailViewModel

    required init(space: Space) {
        viewModel = Container.shared.internetArchiveDetailViewModel(space)
        super.init(rootView: InternetArchiveDetailView(viewModel: viewModel))

        viewModel.onDismiss = { [weak self] in
            self?.dismissOrPop(completion: nil)
        }
        viewModel.onBackButtonVisibility = { [weak self] hidden in
            self?.navigationItem.hidesBackButton = hidden
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.title = viewModel.space.prettyName
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("InternetArchiveDetails")
    }

    /// Pops if in a navigation stack, otherwise dismisses.
    private func dismissOrPop(completion: (() -> Void)?) {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
            if let completion = completion {
                nav.transitionCoordinator?.animate(alongsideTransition: nil, completion: { _ in completion() })
            }
        } else {
            dismiss(animated: true, completion: completion)
        }
    }
}
