//
//  PrivateServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class PrivateServerViewController: FormViewController {

    private let urlRow = URLRow() {
        var value: URL?

        if let baseUrl = WebDavServer.baseUrl {
            value = URL(string: baseUrl)
        }

        if let subfolders = WebDavServer.subfolders?.split(separator: "/") {
            for s in subfolders {
                value?.appendPathComponent(String(s))
            }
        }

        $0.title = "Server URL".localize()
        $0.value = value
        $0.add(rule: RuleRequired())
    }

    private let userNameRow = AccountRow() {
        $0.title = "User Name".localize()
        $0.value = WebDavServer.username
        $0.add(rule: RuleRequired())
    }

    private let passwordRow = PasswordRow() {
        $0.title = "Password".localize()
        $0.value = WebDavServer.password
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Private Server".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Connect".localize(), style: .done, target: self,
            action: #selector(connect))

        form
            +++ Section()

            <<< urlRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            <<< userNameRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            <<< passwordRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

        form.validate()
        enableConnect()
    }


    // MARK: Actions

    @objc func connect() {
        WebDavServer.baseUrl = urlRow.value?.absoluteString
        WebDavServer.subfolders = nil
        WebDavServer.username = userNameRow.value
        WebDavServer.password = passwordRow.value

        navigationController?.popViewController(animated: true)
    }


    // MARK: Private Methods

    private func enableConnect() {
        navigationItem.rightBarButtonItem?.isEnabled = urlRow.isValid
            && userNameRow.isValid && passwordRow.isValid
    }
}
