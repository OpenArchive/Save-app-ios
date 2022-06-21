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
            claimLb?.text = String(
                format: NSLocalizedString("Share%1$@Archive%1$@Verify%1$@Encrypt", comment: "Placeholders will be replaced by newline"),
                "\n")
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
}
