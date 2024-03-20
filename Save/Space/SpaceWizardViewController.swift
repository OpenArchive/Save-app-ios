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

    func next(_ vc: UIViewController, pos: Int)

    func dismiss(success: Bool)
}

protocol WizardDelegatable: AnyObject {

    var delegate: WizardDelegate? { get set }
}

class SpaceWizardViewController: BasePageViewController, WizardDelegate {

    weak var delegate: MainViewController?

    private lazy var viewControllers: [UIViewController] = [UIStoryboard.main.instantiate(SpaceTypeViewController.self)]

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))

        hideKeyboardOnOutsideTap()

        back()
    }


    // MARK: WizardDelegate

    func back() {
        // Users can only ever go back to the first page.
        page = 0

        let vc = viewControllers[page]
        (vc as? WizardDelegatable)?.delegate = self

        pageVc.setViewControllers([vc], direction: getDirection(forward: false), animated: true)

        pageControl.currentPage = page
    }

    func next(_ vc: UIViewController, pos: Int) {
        (vc as? WizardDelegatable)?.delegate = self

        assert(pos <= viewControllers.count, "\(String(describing: type(of: self)))#next: pos cannot be bigger than \(viewControllers.count)")

        if pos < viewControllers.count {
            viewControllers[pos] = vc
            page = pos
        }
        else if pos == viewControllers.count {
            viewControllers.append(vc)
            page = pos
        }

        // Hide navigation bar on success scene.
        navigationController?.setNavigationBarHidden(pos > 1, animated: true)

        pageVc.setViewControllers([vc], direction: getDirection(), animated: true)
        
        self.pageControl.currentPage = self.page
    }

    func dismiss(success: Bool) {
        dismiss(animated: true)

        if success {
            delegate?.addFolder()
        }
    }


    // MARK: UIPageViewControllerDataSource

    override func pageViewController(_ pageViewController: UIPageViewController, 
                            viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        if let i = viewControllers.firstIndex(of: viewController), i > 0 && i < 2 /* Do not allow paging back from success scene */ {
            return viewControllers[i - 1]
        }

        return nil
    }

    override func pageViewController(_ pageViewController: UIPageViewController, 
                            viewControllerAfter viewController: UIViewController) -> UIViewController? 
    {
        if let i = viewControllers.firstIndex(of: viewController), i < viewControllers.count - 1 {
            return viewControllers[i + 1]
        }

        return nil
    }


    // MARK: UIPageViewControllerDelegate

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool)
    {
        if completed,
           let vc = pageViewController.viewControllers?.first,
           let i = viewControllers.firstIndex(of: vc)
        {
            page = i

            pageControl.currentPage = page
        }
    }
}
