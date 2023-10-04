//
//  SlideshowViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import OrbotKit

class SlideshowViewController: UIViewController, UIPageViewControllerDataSource,
                               UIPageViewControllerDelegate, SlideViewControllerDelegate
{

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var doneBt: UIButton! {
        didSet {
            doneBt.setTitle(NSLocalizedString("Done", comment: ""))
        }
    }

    @IBOutlet weak var doneIcon: UIImageView!
    @IBOutlet weak var pageControl: UIPageControl! {
        didSet {
            pageControl.numberOfPages = Self.slides.count
        }
    }

    private static let slides = [
        Slide(
            heading: NSLocalizedString("Save to a safe place.", comment: ""),
            text: NSLocalizedString("Connect to a secure server or the Internet Archive to upload photos and videos from your phone.", comment: ""),
            illustration: "safe-place-screen"),

        Slide(
            heading: NSLocalizedString("Stay organized.", comment: ""),
            text: NSLocalizedString("Organize your media into projects.", comment: ""),
            illustration: "stay-organized-screen"),

        Slide(
            heading: NSLocalizedString("Store the facts.", comment: ""),
            text: NSLocalizedString("Capture notes, location and people with each piece of media.", comment: ""),
            illustration: "save-the-facts"),

        Slide(
            heading: NSLocalizedString("Ensure authenticity.", comment: ""),
            text: String(format: NSLocalizedString("Include your credentials while %@ adds extra metadata to help with chain of custody and verification workflows.", comment: ""), Bundle.main.displayName),
            illustration: "Ensure-Authenticity-screen"),

        Slide(
            heading: NSLocalizedString("Save over Tor.", comment: ""),
            text: {
                OrbotKit.shared.installed
                ? NSLocalizedString("To enable advanced network security, you should enable the \"Transfer via Orbot only\" option now or later in settings.", comment: "")
                : NSLocalizedString("To enable advanced network security, please install Orbot iOS.", comment: "")
            },
            buttonText: {
                OrbotKit.shared.installed
                ? NSLocalizedString("Enable", comment: "")
                : NSLocalizedString("Install", comment: "")
            },
            illustration: "save-over-tor-screen")
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reload()

        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self)
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

        if index >= Self.slides.count - 1 {
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
                (navC.topViewController as? MainViewController)?.addSpace()
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
        let newPage = min(page + 1, Self.slides.count - 1)

        if page != newPage {
            page = newPage
            pageVc.setViewControllers([getSlide(page)], direction: getDirection(), animated: true)

            refresh()
        }
    }

    // MARK: Private Methods

    @objc
    private func reload() {
        pageVc.setViewControllers([getSlide(page)], direction: .forward, animated: false)

        refresh(animate: false)
    }

    private func refresh(animate: Bool = true) {
        doneBt.isHidden = page < Self.slides.count - 1
        doneIcon.isHidden = doneBt.isHidden

        pageControl.currentPage = page

        if animate {
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }
    }

    private func getSlide(_ index: Int) -> SlideViewController {
        let slide = Self.slides[index]

        let vc = UIStoryboard.main.instantiate(SlideViewController.self)

        vc.slide = slide
        vc.delegate = self
        vc.index = index

        return vc
    }


    // MARK: SlideViewControllerDelegate

    func buttonPressed() {
        // Button should only appear on last page, therefore ignore all other presses,
        // which might happen, even though the height of that button should be 0.
        guard page >= Self.slides.count - 1 else {
            return
        }

        if !OrbotKit.shared.installed {
            UIApplication.shared.open(OrbotManager.appStoreLink)
        }
        else {
            OrbotManager.shared.alertToken { [weak self] in
                Settings.useOrbot = true
                OrbotManager.shared.start()

                self?.done()
            }
        }
    }


    // MARK: Private Methods

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
