//
//  SlideshowViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import OrbotKit
import TorManager

class SlideshowViewController: BasePageViewController, SlideViewControllerDelegate
{

    @IBOutlet weak var skipBt: UIButton! {
        didSet {
            skipBt.setTitle(NSLocalizedString("Skip", comment: ""))
        }
    }

    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle("")
        }
    }


    private static let slides = [
        SlideViewController.Slide(
            heading: NSLocalizedString("Share", comment: "").localizedUppercase,
            text: NSLocalizedString(
                "Upload verified media to your chosen server. Add a Creative Commons license to communicate your intentions for future use.",
                comment: ""),
            illustration: "onboarding-hand"),

        SlideViewController.Slide(
            heading: NSLocalizedString("Archive", comment: "").localizedUppercase,
            text: NSLocalizedString(
                "Keep your media safe and organized for the long-term and create in-app project folders that map to your personal or organizational media archive.",
                comment: ""),
            illustration: "onboarding-laptop"),

        SlideViewController.Slide(
            heading: NSLocalizedString("Verify", comment: "").localizedUppercase,
            text: NSLocalizedString(
                "Authenticate your media with a SHA-256 cryptographic verification hash, and optional ProofMode. Add critical metadata like notes, people, and location with each upload.",
                comment: ""),
            illustration: "onboarding-handheld"),

        SlideViewController.Slide(
            heading: NSLocalizedString("Encrypt", comment: "").localizedUppercase,
            text: { _ in
                String(
                    format: NSLocalizedString(
                        "Automatically upload over TLS (Transport Layer Security) and enable %1$@ (The Onion Router) in-app to protect your media in transit.",
                        comment: "Placeholder 1 is 'Tor'"), TorManager.torName)
            },
            text2: { view in
                let linkText = String(format: NSLocalizedString(
                    "Enable \"Transfer via %@ only\"",
                    comment: "Placeholder is 'Tor'"), TorManager.torName)

                let text = NSLocalizedString(
                    "%@ for advanced network security.",
                    comment: "Placeholder is your translation of 'Enable \"Transfer via Orbot or built-in Tor only\"'")

                return String(format: text, linkText)
                    .attributed
                    .link(part: linkText, into: view)
            },
            illustration: "onboarding-onion"),
    ]


    override func viewDidLoad() {
        super.viewDidLoad()

        pageControl.numberOfPages = Self.slides.count
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

    override func pageViewController(_ pageViewController: UIPageViewController,
                                     viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let index = (viewController as? SlideViewController)?.index ?? Int.min

        if index <= 0 {
            return nil
        }

        return getSlide(index - 1)
    }

    override func pageViewController(_ pageViewController: UIPageViewController,
                                     viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
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
                            transitionCompleted completed: Bool) 
    {
        if completed {
            page = (pageViewController.viewControllers?.first as? SlideViewController)?.index ?? 0
            refresh()
        }
    }


    // MARK: SlideViewControllerDelegate

    func text2Pressed() {
        // Button should only appear on last page, therefore ignore all other presses,
        // which might happen, even though the height of that button should be 0.
        guard page >= Self.slides.count - 1 else {
            return
        }

        Settings.useTor = true

        skip()
    }


    // MARK: Actions

    @IBAction func skip() {
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
        else {
            skip()
        }
    }


    // MARK: Private Methods

    @objc
    private func reload() {
        pageVc.setViewControllers([getSlide(page)], direction: .forward, animated: false)

        refresh(animate: false)
    }

    private func refresh(animate: Bool = true) {
        let last = page >= Self.slides.count - 1
        skipBt.isHidden = last
        nextBt.setImage(.init(systemName: last ? "arrow.right" : "checkmark"))

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
}
