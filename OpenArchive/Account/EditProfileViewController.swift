//
//  EditProfileViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 16.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class EditProfileViewController: BaseViewController, UITextFieldDelegate {

    @IBOutlet weak var avatarImg: UIImageView!
    @IBOutlet weak var aliasTf: UITextField!
    @IBOutlet weak var roleTf: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardOnOutsideTap()

        aliasTf.text = Profile.alias
        roleTf.text = Profile.role
    }
    

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {

        case aliasTf:
            roleTf.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
        }

        return true
    }


    // MARK: Actions

    @IBAction func changed(_ sender: UITextField) {
        switch sender {
        case aliasTf:
            Profile.alias = sender.text
        default:
            Profile.role = sender.text
        }
    }
}
