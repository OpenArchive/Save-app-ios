//
//  ClaimViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.01.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit

class ClaimViewController: UIViewController {

    @IBOutlet weak var nextArrow: UIImageView!
    @IBOutlet weak var claimLb: UILabel? {
        didSet {
            let text = String(
                format: NSLocalizedString("Share%1$@Archive%1$@Verify%1$@Encrypt",
                                          comment: "Placeholders will be replaced by newline"),
                "\n")
                .attributed

            text.colorize(with: .accent, index: text.startIndex)

            var rest = text.startIndex ..< text.endIndex

            while let range = text.range(of: "\n", range: rest) {
                text.colorize(with: .accent, index: range.upperBound)

                rest = range.upperBound ..< text.endIndex
            }

            claimLb?.attributedText = text
            claimLb?.font = UIFont(name: "Montserrat-Bold", size: 60)
        }
    }

    @IBOutlet weak var subtitleLb: UILabel? {
        didSet {
            subtitleLb?.font = .montserrat(forTextStyle: .body,with: .traitUIOptimized)
            subtitleLb?.adjustsFontSizeToFitWidth = true
            subtitleLb?.text = NSLocalizedString("Secure Mobile Media Preservation", comment: "")
        }
    }

    @IBOutlet weak var nextBt: UILabel? {
        didSet {
            nextBt?.font = .montserrat(forTextStyle: .body,with: .traitUIOptimized)
            nextBt?.adjustsFontSizeToFitWidth = true
            nextBt?.text = NSLocalizedString("Get Started", comment: "")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        claimLb?.fontName = UIFont.blackFontName
    }
    override func viewDidLoad() {
        animateArrow()
    }
    func animateArrow() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 3.0
        animation.values = [-10, 10, -8, 8, -5, 5, 0, 0, 0, 0]  // Added zeros for pause at end
        animation.repeatCount = .infinity
        nextArrow.layer.add(animation, forKey: "shake")
    }
    
    func stopArrowAnimation() {
        nextArrow.layer.removeAllAnimations()
    }
    override func viewWillDisappear(_ animated: Bool) {
        stopArrowAnimation()
    }
}
