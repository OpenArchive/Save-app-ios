//
//  SpaceWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

protocol WizardDelegate: AnyObject {

    func next(_ vc: UIViewController)
}

class SpaceWizardViewController: BaseViewController, WizardDelegate {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var container: UIView!

    private var current: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))

        let vc = UIStoryboard.main.instantiate(SpaceTypeViewController.self)
        vc.delegate = self

        next(vc)
    }


    // MARK: WizardDelegate

    func next(_ vc: UIViewController) {
        if let current = current {
            pageControl.currentPage = pageControl.currentPage + 1

            current.removeFromParent()

            current.view.hide(animated: true) { _ in
                current.view.removeFromSuperview()

                current.didMove(toParent: nil)
            }
        }

        addChild(vc)

        vc.view.isHidden = true
        container.addSubview(vc.view)

        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        vc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        vc.view.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        vc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        vc.view.show2(animated: current != nil) { [weak self] _ in
            vc.didMove(toParent: self)

            self?.current = vc
        }
    }
}
