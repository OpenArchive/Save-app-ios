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

    @IBOutlet weak var authenticateBt: UIButton! {
        didSet {
            authenticateBt.setTitle(NSLocalizedString("Authenticate", comment: ""))
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

        updateUi()
    }

    override func afterSpaceRemoved() {
        GIDSignIn.sharedInstance.signOut()
    }


    @IBAction func authenticate() {
        GdriveWizardViewController.authenticate(self, space: space as! GdriveSpace) { [weak self] in
            self?.updateUi()
        }
    }

    private func updateUi() {
        let ok = GdriveConduit.user != nil

        gdriveIdTb.text = (space as? GdriveSpace)?.email ?? space?.username
        gdriveIdTb.status = ok ? .good : .bad

        authenticateBt.toggle(!ok)
    }
}
