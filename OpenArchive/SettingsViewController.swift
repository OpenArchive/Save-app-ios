//
//  SettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet var accessKeyTf: UITextField!
    @IBOutlet var secretKeyTf: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        accessKeyTf.text = InternetArchive.accessKey
        secretKeyTf.text = InternetArchive.secretKey
    }

    @IBAction func changed(_ sender: UITextField) {
        switch sender {
        case accessKeyTf:
            InternetArchive.accessKey = sender.text
        default:
            InternetArchive.secretKey = sender.text
        }
    }
}
