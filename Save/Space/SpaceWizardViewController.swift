//
//  SpaceWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

protocol WizardDelegate: AnyObject {

    func back()

    func next(_ vc: UIViewController)
}

protocol WizardDelegatable: AnyObject {

    var delegate: WizardDelegate? { get set }
}

class SpaceWizardViewController: BaseViewController, WizardDelegate {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var container: UIView!


    private var viewControllers = [UIViewController]() {
        didSet {
            if currentIdx >= viewControllers.count {
                currentIdx = viewControllers.count - 1
            }
        }
    }

    private var currentIdx = -1

    private var current: UIViewController? {
        if viewControllers.count > 0 {
            return viewControllers[max(0, min(currentIdx, viewControllers.count - 1))]
        }

        return nil
    }



    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))

        let vc = UIStoryboard.main.instantiate(SpaceTypeViewController.self)
        vc.delegate = self

        next(vc)
    }


    // MARK: WizardDelegate

    func back() {
        if let current = current {
            remove(current)

            viewControllers.removeAll { $0 == current }
        }

        add(current)

        pageControl.currentPage = currentIdx
    }

    func next(_ vc: UIViewController) {
        (vc as? WizardDelegatable)?.delegate = self

        remove(current)

        viewControllers.append(vc)
        currentIdx += 1

        add(vc)

        pageControl.currentPage = currentIdx
    }


    // MARK: Private Methods

    private func remove(_ vc: UIViewController?) {
        guard let vc = vc else {
            return
        }

        vc.removeFromParent()

        vc.view.hide(animated: true) { _ in
            vc.view.removeFromSuperview()

            vc.didMove(toParent: nil)
        }
    }

    private func add(_ vc: UIViewController?) {
        guard let vc = vc else {
            return
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
        }
    }
}
