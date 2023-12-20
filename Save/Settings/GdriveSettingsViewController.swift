//
//  GdriveSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import GoogleSignIn

class GdriveSettingsViewController: SpaceSettingsViewController {

    @IBOutlet weak var gdriveIdLb: UILabel! {
        didSet {
            gdriveIdLb.text = String(format: NSLocalizedString("%@ ID", comment: "Placeholder is 'Google'"),
                                      "Google")
        }
    }

    @IBOutlet weak var gdriveIdTb: TextBox! {
        didSet {
            gdriveIdTb.placeholder = String(format: NSLocalizedString("%@ ID", comment: "Placeholder is 'Google'"),
                                            "Google")
            gdriveIdTb.status = .good
            gdriveIdTb.isEnabled = false
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        if space == nil || !(space is GdriveSpace), let space = SelectedSpace.space as? GdriveSpace {
            self.space = space
        }
        else {
            return dismiss(nil)
        }

        navigationItem.title = GdriveSpace.defaultPrettyName

        gdriveIdTb.text = (space as? GdriveSpace)?.email ?? space?.username
    }

    override func afterSpaceRemoved() {
        GIDSignIn.sharedInstance.signOut()
    }
}
