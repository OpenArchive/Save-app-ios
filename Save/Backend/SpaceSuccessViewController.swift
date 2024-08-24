//
//  SpaceSuccessViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceSuccessViewController: BaseViewController, WizardDelegatable {

    weak var delegate: WizardDelegate?

    var spaceName = ""


    @IBOutlet weak var titleLb: UILabel!

    @IBOutlet weak var doneBt: UIButton! {
        didSet {
            doneBt.setTitle(NSLocalizedString("Done", comment: ""))
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        titleLb.text = String(
            format: NSLocalizedString("You have successfully connected to %@!",
                                      comment: "Placeholder is a server type or name"),
            spaceName)
    }

    @IBAction func done() {
        delegate?.dismiss(success: true)
    }
}
