//
//  ClaimViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.01.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit

class ClaimViewController: UIViewController {

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
        }
    }

    @IBOutlet weak var subtitleLb: UILabel? {
        didSet {
            subtitleLb?.font = .montserrat(forTextStyle: .headline)
            subtitleLb?.adjustsFontSizeToFitWidth = true
            subtitleLb?.text = NSLocalizedString("Secure Mobile Media Preservation", comment: "")
        }
    }

    @IBOutlet weak var nextBt: UILabel? {
        didSet {
            nextBt?.font = .montserrat(forTextStyle: .headline)
            nextBt?.adjustsFontSizeToFitWidth = true
            nextBt?.text = NSLocalizedString("Get Started", comment: "")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Force to Montserrat-Black again, after we destroyed it with the appearance proxy.
        // Needs to run here, otherwise, it'll be too early and the appearance proxy will win again.
        claimLb?.fontName = UIFont.blackFontName
    }
}
