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
    @IBOutlet weak var doneBt: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!

    private static let data = [
    [
        "heading": "Save to a safe place.".localize(),
        "text": "Connect to a secure server or the internet archive to upload photos and videos from your phone.".localize(),
    ],
    [
        "heading": "Stay organized.".localize(),
        "text": "Organize your media into projects.".localize(),
    ],
    [
        "heading": "Store the facts.".localize(),
        "text": "Capture notes, location and people with each piece of media.".localize(),
    ],
    [
        "heading": "Ensure authenticity.".localize(),
        "text": "Include your credentials while Save adds extra metadata to help with chain of custody and verification workflows.".localize(),
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

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)
        pageVc.setViewControllers([getSlide(0)], direction: .forward, animated: false)

        refresh()
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
        navigationController?.setViewControllers(
            [UIStoryboard.main.instantiate(ConnectSpaceViewController.self)],
            animated: true)
    }

    @IBAction func pageChanged() {
        let direction: UIPageViewController.NavigationDirection = page < pageControl.currentPage ? .forward : .reverse
        page = pageControl.currentPage

        pageVc.setViewControllers([getSlide(page)], direction: direction, animated: true)

        refresh()
    }

    @IBAction func forward() {
        let newPage = min(page + 1, SlideshowViewController.data.count - 1)

        if page != newPage {
            page = newPage
            pageVc.setViewControllers([getSlide(page)], direction: .forward, animated: true)

            refresh()
        }
    }

    // MARK: Private Methods

    private func refresh() {
        doneBt.isHidden = page < SlideshowViewController.data.count - 1

        pageControl.currentPage = page

        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }

    private func getSlide(_ index: Int) -> SlideViewController {
        let data = SlideshowViewController.data[index]

        let vc = UIStoryboard.main.instantiate(SlideViewController.self)

        vc.heading = data["heading"]
        vc.text = data["text"]
        vc.index = index

        return vc
    }
}
