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

    @IBOutlet weak var bottomButtonContraint: NSLayoutConstraint!
    @IBOutlet weak var SlideTopContraint: NSLayoutConstraint!
    @IBOutlet weak var skipBt: UIButton! {
        didSet {
            skipBt.setTitle(NSLocalizedString("Skip", comment: ""))
            skipBt.titleLabel?.font = .montserrat(forTextStyle: .body,with: .traitUIOptimized)
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
                let style: UIFont.TextStyle = .subheadline
                let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
                let letterSpacing = baseSize * 0.02
                let font = UIFont(name: "Montserrat-Regular", size: baseSize)
                    ?? UIFont.preferredFont(forTextStyle: style)

                // Line height
                let lineHeight: CGFloat = 22.0
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = lineHeight
                paragraphStyle.maximumLineHeight = lineHeight
                paragraphStyle.alignment = .left
                
                let text = NSLocalizedString(
                    "Send your media securely to private servers and lock the app with a pin.",
                    comment: ""
                )
               
            
                return NSAttributedString(string: text, attributes: [
                    .font: font,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraphStyle
                ])
            },
            illustration: "onboarding-hand"
        ),

        SlideViewController.Slide(
            heading: NSLocalizedString("Archive", comment: "").localizedUppercase,
            text: { _ in
               
                var style: UIFont.TextStyle =  .subheadline

                print(UIScreen.main.bounds.height)
                let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
                let letterSpacing =  0.02
                let lineHeight: CGFloat =  22
                let font = UIFont(name: "Montserrat-Regular", size: baseSize)
                    ?? UIFont.preferredFont(forTextStyle: style)

                let paragraphStyle = NSMutableParagraphStyle()
                if UIScreen.main.bounds.height > 812 {
                    paragraphStyle.minimumLineHeight = lineHeight
                    paragraphStyle.maximumLineHeight = lineHeight
                }
                paragraphStyle.alignment = .left
            

                let blackColor = UIColor.label

                // Localized text with placeholders
                let localizedString = NSLocalizedString(
                    "Keep your media verifiable, safe and organized for the long-term by uploading it to private or public servers like Nextcloud or the Internet Archive. \nCommunicate your intentions for future use by adding a %@",
                    comment: "Archive message"
                )

                // Create the "Creative Commons License" link text
                let licenseText = NSLocalizedString("Creative Commons License.", comment: "Creative Commons License")
                let licenseUrl = URL(string: "https://creativecommons.org")!

                let licenseAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                     .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: blackColor,
                    .link: licenseUrl
                ]
                let licenseAttributed = NSAttributedString(string: licenseText, attributes: licenseAttributes)

                // Split localized string into components
                let localizedComponents = localizedString.components(separatedBy: "%@")

                // Construct final attributed string
                let attributedText = NSMutableAttributedString(string: localizedComponents[0], attributes: [
                    .font: font,
                    //.kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: blackColor,
                ])
                attributedText.append(licenseAttributed)

                return attributedText
            },
            illustration: "onboarding-laptop"
        ),
        SlideViewController.Slide(
            heading: NSLocalizedString("Verify", comment: "").localizedUppercase,
            text: { _ in

                let style: UIFont.TextStyle = .subheadline
                let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
                let letterSpacing = baseSize * 0.02
                let font = UIFont(name: "Montserrat-Regular", size: baseSize)
                    ?? UIFont.preferredFont(forTextStyle: style)

                // Line height
                let lineHeight: CGFloat = 22.0
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = lineHeight
                paragraphStyle.maximumLineHeight = lineHeight
                paragraphStyle.alignment = .left
                
                let blackColor = UIColor.label

                // Localized text with placeholders
                let localizedString = NSLocalizedString(
                    "Authenticate and verify your media with sha256 hashes and %@",
                    comment: "Verification message"
                )

                // Create the "ProofMode" link text
                let proofModeText = NSLocalizedString("ProofMode.", comment: "ProofMode")
                let proofModeUrl = URL(string: "https://proofmode.org")!

                let proofModeAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: blackColor,
                    .link: proofModeUrl
                ]
                let proofModeAttributed = NSAttributedString(string: proofModeText, attributes: proofModeAttributes)

                // Split localized string into components
                let localizedComponents = localizedString.components(separatedBy: "%@")

                // Construct final attributed string
                let attributedText = NSMutableAttributedString(string: localizedComponents[0], attributes: [
                    .font: font,
                    .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: blackColor,
                ])
                attributedText.append(proofModeAttributed)

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
                let style: UIFont.TextStyle = .subheadline
                let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
                let letterSpacing = baseSize * 0.02
                let lineHeight: CGFloat = UIScreen.main.bounds.height <= 780 ? 18 :  22
                let font = UIFont(name: "Montserrat-Regular", size: baseSize)
                    ?? UIFont.preferredFont(forTextStyle: style)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = lineHeight
                paragraphStyle.maximumLineHeight = lineHeight
                paragraphStyle.alignment = .left
           
                let saveText = NSLocalizedString("Save", comment: "Save")
                let torText = NSLocalizedString("Tor", comment: "Tor")
                let torUrl = URL(string: "https://www.torproject.org")!
               
               // paragraphStyle.lineSpacing = 3
              
                let attributedText = NSMutableAttributedString()

              
                let blackColor = UIColor.label

                // Bold and italic font for "Save"
                let descriptor = font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])
                let boldItalicFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: baseSize)
                let saveAttributed = NSAttributedString(string: saveText, attributes: [
                    .font: boldItalicFont,
                    .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: blackColor
                ])

                // Link text for "Tor"
                let torAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: blackColor,
                    .link: torUrl
                ]
                let torAttributed = NSAttributedString(string: torText, attributes: torAttributes)

                // Format the localized string
                let localizedComponents = String(format: localizedString, "%@", "%@").components(separatedBy: "%@")
                attributedText.append(NSAttributedString(string: localizedComponents[0], attributes: [
                    .font: font,
                    .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: blackColor,
                
                ]))
                attributedText.append(saveAttributed)
                attributedText.append(NSAttributedString(string: localizedComponents[1], attributes: [
                    .font: font,
                    .kern: letterSpacing,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: blackColor
                
                ]))
                attributedText.append(torAttributed)
                attributedText.append(NSAttributedString(string: localizedComponents[2], attributes: [
                    .font: font,
                    .foregroundColor: blackColor
                ]))

                return attributedText
            },
            illustration: "onboarding-onion"
        )
    ]



    override func viewDidLoad() {
        super.viewDidLoad()
        if UIScreen.main.bounds.height <= 667 {
            bottomButtonContraint.constant = 16
        
        } else {
            bottomButtonContraint.constant = 25
          
        }
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
            DispatchQueue.main.async {
                       self.refresh()
                   }
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
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                (navC.topViewController as? MainViewController)?.addSpace()
//            }
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
        nextBt.setImage(.init(imageLiteralResourceName: last ? "check" :"forward_arrow"))
       
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
