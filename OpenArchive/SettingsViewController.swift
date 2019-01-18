//
//  SettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var iaAccessKeyTf: UITextField!
    @IBOutlet var iaSecretKeyTf: UITextField!
    @IBOutlet var wdBaseUrlTf: UITextField!
    @IBOutlet var wdSubfoldersTf: UITextField!
    @IBOutlet var wdUsernameTf: UITextField!
    @IBOutlet var wdPasswordTf: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        iaAccessKeyTf.text = InternetArchive.accessKey
        iaSecretKeyTf.text = InternetArchive.secretKey
//        wdBaseUrlTf.text = WebDavServer.baseUrl
//        wdSubfoldersTf.text = WebDavServer.subfolders
//        wdUsernameTf.text = WebDavServer.username
//        wdPasswordTf.text = WebDavServer.password
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {

        case iaAccessKeyTf:
            iaSecretKeyTf.becomeFirstResponder()
        case wdBaseUrlTf:
            wdSubfoldersTf.becomeFirstResponder()
        case wdSubfoldersTf:
            wdUsernameTf.becomeFirstResponder()
        case wdUsernameTf:
            wdPasswordTf.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
        }

        return true
    }

    // MARK: Actions
    @IBAction func changed(_ sender: UITextField) {
        switch sender {
        case iaAccessKeyTf:
            InternetArchive.accessKey = sender.text
        case iaSecretKeyTf:
            InternetArchive.secretKey = sender.text
//        case wdBaseUrlTf:
//            WebDavServer.baseUrl = sender.text
//        case wdSubfoldersTf:
//            WebDavServer.subfolders = sender.text
//        case wdUsernameTf:
//            WebDavServer.username = sender.text
        default:
//            WebDavServer.password = sender.text
            break
        }
    }
}
