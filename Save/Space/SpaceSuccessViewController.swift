//
//  SpaceSuccessViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class SpaceSuccessViewController: UIHostingController<SpaceSuccessView> {

    var spaceName = ""

    required init(spaceName: String = "") {
        self.spaceName = spaceName
        let placeholder = SpaceSuccessView(spaceName: spaceName, onDone: {})
        super.init(rootView: placeholder)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        title = NSLocalizedString("Setup Complete", comment: "")

        rootView = SpaceSuccessView(spaceName: spaceName) { [weak self] in
            self?.done()
        }
    }

    private func done() {
        if let navigationController = navigationController {
            if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {
                navigationController.popToViewController(existingVC, animated: true)
            } else {
                let newVC = MainViewController()
                navigationController.pushViewController(newVC, animated: true)
            }
        }
    }
}
