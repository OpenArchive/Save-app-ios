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

        claimLb.text = "Share%Archive%Verify%Encrypt".localize(value: "\n")
    }
}
