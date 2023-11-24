//
//  DropboxSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class DropboxSettingsViewController: SpaceSettingsViewController {

    @IBOutlet weak var dropboxIdLb: UILabel! {
        didSet {
            dropboxIdLb.text = String(format: NSLocalizedString("%@ ID", comment: "Placeholder is 'Dropbox'"),
                                      DropboxSpace.defaultPrettyName)
        }
    }

    @IBOutlet weak var dropboxIdTb: TextBox! {
        didSet {
            dropboxIdTb.placeholder = String(format: NSLocalizedString("%@ ID", comment: "Placeholder is 'Dropbox'"),
                                             DropboxSpace.defaultPrettyName)
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = DropboxSpace.defaultPrettyName

        navigationController?.setNavigationBarHidden(false, animated: true)


        if space == nil || !(space is DropboxSpace), let space = SelectedSpace.space as? DropboxSpace {
            self.space = space
        }
        else {
            return dismiss(nil)
        }

        dropboxIdTb.text = (space as? DropboxSpace)?.email ?? space?.username
        dropboxIdTb.status = .good
    }
}
