//
//  WebDavSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
class WebDavSettingsViewController: SpaceSettingsViewController, TextBoxDelegate,UpdateNameDelegate {

    @IBOutlet weak var serverLb: UILabel! {
        didSet {
            serverLb.text = NSLocalizedString("Server Info", comment: "")
        }
    }

    @IBOutlet weak var urlTb: TextBox! {
        didSet {
            urlTb.placeholder = NSLocalizedString("Server URL", comment: "")
            urlTb.status = .good
            urlTb.isEnabled = false
        }
    }

    @IBOutlet weak var nameTb: TextBox! {
        didSet {
            nameTb.placeholder = NSLocalizedString("Server Name (Optional)", comment: "")
            nameTb.delegate = self
        }
    }

    @IBOutlet weak var accountLb: UILabel! {
        didSet {
            accountLb.text = NSLocalizedString("Account", comment: "")
        }
    }

    @IBOutlet weak var usernameTb: TextBox! {
        didSet {
            usernameTb.placeholder = NSLocalizedString("Username", comment: "")
            usernameTb.status = .good
            usernameTb.isEnabled = false
        }
    }

    @IBOutlet weak var passwordTb: TextBox! {
        didSet {
            passwordTb.placeholder = NSLocalizedString("Password", comment: "")
            passwordTb.status = .good
            passwordTb.isEnabled = false
        }
    }

    @IBOutlet weak var nextcloudLb: UILabel! {
        didSet {
            nextcloudLb.text = NSLocalizedString("Use Upload Chunking (Nextcloud Only)", comment: "")
        }
    }

    @IBOutlet weak var nextcloudSw: UISwitch! {
        didSet {
            nextcloudSw.addTarget(self, action: #selector(nextcloudChanged), for: .valueChanged)
        }
    }

    @IBOutlet weak var nextcloudDescLb: UILabel! {
        didSet {
            nextcloudDescLb.text = NSLocalizedString(
                "\"Chunking\" uploads media in pieces so you don't have to restart your upload if your connection is interrupted.",
                comment: "")
        }
    }

    @IBAction func viewLicences(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // Replace "Main" with your storyboard name
        if let viewController = storyboard.instantiateViewController(withIdentifier: "CreateCCLViewController") as? CreateCCLViewController {
            viewController.isFromCreateServer = false
            viewController.editSpace = space
            viewController.delegate = self
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Edit Private Server", comment: "")
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
        urlTb.text = space?.url?.absoluteString
        nameTb.text = space?.name
        usernameTb.text = space?.username
        passwordTb.text = "abcdefgh" // Don't populate with real password
        nextcloudSw.isOn = space?.isNextcloud ?? false
    }


    // MARK: TextBoxDelegate

    func textBox(didUpdate textBox: TextBox) {
        guard let space = space as? WebDavSpace else {
            return
        }

        let name = nameTb.text ?? ""

        space.name = name.isEmpty ? nil : name

        Db.writeConn?.setObject(space)
    }

    func textBox(shouldReturn textBox: TextBox) -> Bool {
        dismissKeyboard()

        return true
    }


    // MARK: Private Methods

    @objc func nextcloudChanged() {
        guard let space = space as? WebDavSpace else {
            return
        }

        space.isNextcloud = nextcloudSw.isOn

        Db.writeConn?.setObject(space)
    }
    func updateName(_ name: String) {
        self.nameTb.text = name
       }
}
protocol UpdateNameDelegate: AnyObject {
    func updateName(_ name: String)
}
