//
//  SlideshowViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SlideshowViewController: UIViewController, UIPageViewControllerDataSource,
UIPageViewControllerDelegate {

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var doneBt: UIButton! {
        didSet {
            doneBt.setTitle(NSLocalizedString("Done", comment: ""))
        }
    }

    @IBOutlet weak var doneIcon: UIImageView!
    @IBOutlet weak var pageControl: UIPageControl!

    private static let data = [
    [
        "heading": NSLocalizedString("Save to a safe place.", comment: ""),
        "text": NSLocalizedString("Connect to a secure server or the Internet Archive to upload photos and videos from your phone.", comment: ""),
        "illustration": "safe-place-screen",
    ],
    [
        "heading": NSLocalizedString("Stay organized.", comment: ""),
        "text": NSLocalizedString("Organize your media into projects.", comment: ""),
        "illustration": "stay-organized-screen",
    ],
    [
        "heading": NSLocalizedString("Store the facts.", comment: ""),
        "text": NSLocalizedString("Capture notes, location and people with each piece of media.", comment: ""),
        "illustration": "save-the-facts",
    ],
    [
        "heading": NSLocalizedString("Ensure authenticity.", comment: ""),
        "text": String(format: NSLocalizedString("Include your credentials while %@ adds extra metadata to help with chain of custody and verification workflows.", comment: ""), Bundle.main.displayName),
        "illustration": "Ensure-Authenticity-screen",
    ],
    ]

    private var page = 0

    private lazy var pageVc: UIPageViewController = {
        let pageVc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVc.dataSource = self
        pageVc.delegate = self

        return pageVc
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        doneBt.isHidden = true
        doneIcon.isHidden = true

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)
        pageVc.setViewControllers([getSlide(0)], direction: .forward, animated: false)

        refresh(animate: false)
    }


    // MARK: UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {

        let index = (viewController as? SlideViewController)?.index ?? Int.min

        if index <= 0 {
            return nil
        }

        return getSlide(index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {

        let index = (viewController as? SlideViewController)?.index ?? Int.max

        if index >= SlideshowViewController.data.count - 1 {
            return nil
        }

        return getSlide(index + 1)
    }


    // MARK: UIPageViewControllerDelegate

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed {
            page = (pageViewController.viewControllers?.first as? SlideViewController)?.index ?? 0
            refresh()
        }
    }


    // MARK: Actions

    @IBAction func done() {
        Settings.firstRunDone = true

        if let navC = navigationController as? MainNavigationController {
            navC.setRoot()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let mainVc = navC.topViewController as? MainViewController {
                    mainVc.performSegue(withIdentifier: MainViewController.segueShowMenu, sender: mainVc)
                }
            }
        }
    }

    @IBAction func pageChanged() {
        let direction = getDirection(forward: page < pageControl.currentPage)
        page = pageControl.currentPage

        pageVc.setViewControllers([getSlide(page)], direction: direction, animated: true)

        refresh()
    }

    @IBAction func forward() {
        let newPage = min(page + 1, SlideshowViewController.data.count - 1)

        if page != newPage {
            page = newPage
            pageVc.setViewControllers([getSlide(page)], direction: getDirection(), animated: true)

            refresh()
        }
    }

    // MARK: Private Methods

    private func refresh(animate: Bool = true) {
        doneBt.isHidden = page < SlideshowViewController.data.count - 1
        doneIcon.isHidden = doneBt.isHidden

        pageControl.currentPage = page

        if animate {
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }
    }

    private func getSlide(_ index: Int) -> SlideViewController {
        let data = SlideshowViewController.data[index]

        let vc = UIStoryboard.main.instantiate(SlideViewController.self)

        vc.heading = data["heading"]
        vc.text = data["text"]
        vc.illustration = data["illustration"] != nil ? UIImage(named: data["illustration"]!) : nil
        vc.index = index

        return vc
    }

    /**
     Fixes right-to-left direction missmatch.

     Strange: Even though, keywords are reading direction agnostic, animations are wrong, anyway, so
     needs reversal on right-to-left languages.
     */
    private func getDirection(forward: Bool = true) -> UIPageViewController.NavigationDirection {
        var direction: UIPageViewController.NavigationDirection = forward ? .forward : .reverse

        if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            direction = direction == .forward ? .reverse : .forward
        }

        return direction
    }
}
