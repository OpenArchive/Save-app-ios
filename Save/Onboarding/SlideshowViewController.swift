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
            text: { _ in
                let text = NSLocalizedString(
                    "Send your media securely to private servers and lock the app with a pin.",
                    comment: ""
                )
                return NSAttributedString(string: text, attributes: [
                    .font: UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
            },
            illustration: "onboarding-hand"
        ),

        SlideViewController.Slide(
            heading: NSLocalizedString("Archive", comment: "").localizedUppercase,
            text: { _ in
                // Create the main text
                let attributedText = NSMutableAttributedString(string: NSLocalizedString(
                    "Keep your media verifiable, safe and organized for the long-term by uploading it to private or public servers like Nextcloud or the Internet Archive. \nCommunicate your intentions for future use by adding a ",
                    comment: ""
                ), attributes: [
                    .font: UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
                
                // Create the link text
                let linkText = NSLocalizedString("Creative Commons License.", comment: "creative commons license")
                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: UIColor.black, // Black text color
                    .link: URL(string: "https://creativecommons.org")! // Link to Creative Commons website
                ]
                
                // Append the link text to the main text
                attributedText.append(NSAttributedString(string: linkText, attributes: linkAttributes))
                
                return attributedText
            },
            illustration: "onboarding-laptop"
        ),


        SlideViewController.Slide(
            heading: NSLocalizedString("Verify", comment: "").localizedUppercase,
            text: { _ in
                // Create the main text
                let attributedText = NSMutableAttributedString(string: NSLocalizedString(
                    "Authenticate and verify your media with sha256 hashes and ",
                    comment: ""
                ), attributes: [
                    .font: UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
                
                // Create the "ProofMode" link text
                let linkText = NSLocalizedString("ProofMode.", comment: "ProofMode")
                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: UIColor.black, // Ensure the color is black
                    .link: URL(string: "https://proofmode.org")! // Add the URL for the clickable link
                ]
                
                attributedText.append(NSAttributedString(string: linkText, attributes: linkAttributes))
                
                return attributedText
            },
            illustration: "onboarding-handheld"
        ),

        SlideViewController.Slide(
            heading: NSLocalizedString("Encrypt", comment: "").localizedUppercase,
            text: { _ in
                // Localized string with placeholders for "Save" and "Tor"
                let localizedString = NSLocalizedString(
                    "%@ always uploads over TLS (Transport Layer Security) to protect your media in transit. \nTo further enhance security, enable %@ to prevent interception of your media from your phone to the server.",
                    comment: "Describes the encryption feature"
                )

                // Dynamic parts for "Save" and "Tor"
                let saveText = NSLocalizedString("Save", comment: "Save")
                let torText = NSLocalizedString("Tor", comment: "Tor")
                let torUrl = URL(string: "https://www.torproject.org")!

                // Attributed string setup
                let attributedText = NSMutableAttributedString()

                // Font for all text
                let montserratFont = UIFont(name: "Montserrat-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
                let blackColor = UIColor.black

                // Bold and italic font for "Save"
                let boldItalicFont = UIFont(descriptor: montserratFont.fontDescriptor
                    .withSymbolicTraits([.traitBold, .traitItalic]) ?? montserratFont.fontDescriptor, size: 14)
                let saveAttributed = NSAttributedString(string: saveText, attributes: [
                    .font: boldItalicFont,
                    .foregroundColor: blackColor
                ])

                // Link text for "Tor"
                let torAttributes: [NSAttributedString.Key: Any] = [
                    .font: montserratFont,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: blackColor,
                    .link: torUrl
                ]
                let torAttributed = NSAttributedString(string: torText, attributes: torAttributes)

                // Format the localized string
                let localizedComponents = String(format: localizedString, "%@", "%@").components(separatedBy: "%@")
                attributedText.append(NSAttributedString(string: localizedComponents[0], attributes: [
                    .font: montserratFont,
                    .foregroundColor: blackColor
                ]))
                attributedText.append(saveAttributed)
                attributedText.append(NSAttributedString(string: localizedComponents[1], attributes: [
                    .font: montserratFont,
                    .foregroundColor: blackColor
                ]))
                attributedText.append(torAttributed)
                attributedText.append(NSAttributedString(string: localizedComponents[2], attributes: [
                    .font: montserratFont,
                    .foregroundColor: blackColor
                ]))

                return attributedText
            },
            illustration: "onboarding-onion"
        )
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
