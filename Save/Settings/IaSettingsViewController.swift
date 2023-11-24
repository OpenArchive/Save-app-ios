//
//  IaSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class IaSettingsViewController: SpaceSettingsViewController {

    @IBOutlet weak var accessKeyLb: UILabel! {
        didSet {
            accessKeyLb.text = NSLocalizedString("Access Key", comment: "")
        }
    }

    @IBOutlet weak var accessKeyTb: TextBox! {
        didSet {
            accessKeyTb.placeholder = NSLocalizedString("Access Key", comment: "")
        }
    }

    @IBOutlet weak var secretKeyLb: UILabel! {
        didSet {
            secretKeyLb.text = NSLocalizedString("Secret Key", comment: "")
        }
    }

    @IBOutlet weak var secretKeyTb: TextBox! {
        didSet {
            secretKeyTb.placeholder = NSLocalizedString("Secret Key", comment: "")
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = IaSpace.defaultPrettyName

        if space == nil || !(space is IaSpace), let space = SelectedSpace.space as? IaSpace {
            self.space = space
        }
        else {
            return dismiss(nil)
        }

        accessKeyTb.text = space?.username
        accessKeyTb.status = .good
        secretKeyTb.text = space?.password
        secretKeyTb.status = .good
    }
}
