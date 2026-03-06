//
//  ClaimViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.01.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class ClaimViewController: UIHostingController<ClaimView> {

    required init() {
        let placeholder = ClaimView(onNext: {})
        super.init(rootView: placeholder)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)

        rootView = ClaimView { [weak self] in
            self?.goToSlideshow()
        }
    }

    private func goToSlideshow() {
        let vc = UIStoryboard.main.instantiate(SlideshowViewController.self)
        navigationController?.pushViewController(vc, animated: true)
    }
}
