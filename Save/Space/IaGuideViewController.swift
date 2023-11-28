//
//  IaGuideViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 28.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class IaGuideViewController: BasePageViewController {

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString("How to Acquire Keys in 3 Easy Steps", comment: "")
        }
    }

    @IBOutlet weak var nextBt: UIButton!

    private static let slides = [
        IaGuideSlideViewController.Slide(
            text: String(format: NSLocalizedString(
                "Step 1: Log into the %@. If you don't have an account, create one.",
                comment: "Placeholder is 'Internet Archive'"), IaSpace.defaultPrettyName),
            image: "ia-guide-illustration1"),
        IaGuideSlideViewController.Slide(
            text: NSLocalizedString(
                "Step 2: If you are creating a new account, verify your email.",
                comment: ""),
            image: "ia-guide-illustration2"),
        IaGuideSlideViewController.Slide(
            text: NSLocalizedString(
                "Step 3: Generate your API keys by selecting the box and it will auto-load in the app!",
                comment: ""),
            image: "ia-guide-illustration3")]

    override func viewDidLoad() {
        super.viewDidLoad()

        pageVc.setViewControllers([getSlide(page)], direction: .forward, animated: false)

        pageControl.numberOfPages = Self.slides.count

        refresh()
    }


    // MARK: UIPageViewControllerDataSource

    override func pageViewController(_ pageViewController: UIPageViewController,
                                     viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        let index = (viewController as? IaGuideSlideViewController)?.index ?? Int.min

        if index <= 0 {
            return nil
        }

        return getSlide(index - 1)
    }

    override func pageViewController(_ pageViewController: UIPageViewController,
                                     viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let index = (viewController as? IaGuideSlideViewController)?.index ?? Int.max

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
            page = (pageViewController.viewControllers?.first as? IaGuideSlideViewController)?.index ?? 0
            refresh()
        }
    }


    // MARK: Actions

    @IBAction func next() {
        let newPage = min(page + 1, Self.slides.count - 1)

        if page != newPage {
            page = newPage
            pageVc.setViewControllers([getSlide(page)], direction: getDirection(), animated: true)

            refresh()
        }
        else {
            dismiss(completion: nil)
        }
    }


    // MARK: Private

    private func refresh() {
        if page >= Self.slides.count - 1 {
            nextBt.setTitle(NSLocalizedString("Close", comment: ""))
        }
        else {
            nextBt.setTitle(NSLocalizedString("Next", comment: ""))
        }

        pageControl.currentPage = page
    }

    private func getSlide(_ index: Int) -> IaGuideSlideViewController {
        let slide = Self.slides[index]

        let vc = UIStoryboard.main.instantiate(IaGuideSlideViewController.self)

        vc.slide = slide
        vc.index = index

        return vc
    }
}
