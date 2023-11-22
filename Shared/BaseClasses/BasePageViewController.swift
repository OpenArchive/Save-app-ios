//
//  BasePageViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class BasePageViewController: BaseViewController, UIPageViewControllerDataSource, 
                                UIPageViewControllerDelegate
{

    @IBOutlet weak var pageControl: UIPageControl!

    @IBOutlet weak var container: UIView!

    var page = 0

    lazy var pageVc: UIPageViewController = {
        let pageVc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVc.dataSource = self
        pageVc.delegate = self

        return pageVc
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)
    }


    // MARK: UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, 
                            viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        assertionFailure("Needs to be implemented in subclass!")

        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, 
                            viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        assertionFailure("Needs to be implemented in subclass!")

        return nil
    }


    // MARK: Helper Methods

    /**
     Fixes right-to-left direction missmatch.

     Strange: Even though, keywords are reading direction agnostic, animations are wrong, anyway, so
     needs reversal on right-to-left languages.
     */
    func getDirection(forward: Bool = true) -> UIPageViewController.NavigationDirection {
        var direction: UIPageViewController.NavigationDirection = forward ? .forward : .reverse

        if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            direction = direction == .forward ? .reverse : .forward
        }

        return direction
    }
}
