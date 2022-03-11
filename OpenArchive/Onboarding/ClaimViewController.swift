//
//  ClaimViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.01.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit

class ClaimViewController: UIViewController {

    @IBOutlet weak var claimLb: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Don't use Localize's single percent-sign placeholder (%), Transifex
        // will see the following characters as qualifiers to that and won't
        // allow translators to save their translation, if e.g. it doesn't contain "%E".
        //
        // Therefore we replace spaces between words with newlines and hope,
        // that translators don't translate one word with multiple words...
        claimLb.text = NSLocalizedString("Share Archive Verify Encrypt", comment: "")
            .split(using: "\\s+".r).joined(separator: "\n")
    }
}
