//
//  PrivateServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import YapDatabase

class PrivateServerViewController: FormViewController {

    var conf: ServerConfig?

    private let urlRow = URLRow() {
        $0.title = "Server URL".localize()
        $0.add(rule: RuleRequired())
    }

    private let userNameRow = AccountRow() {
        $0.title = "User Name".localize()
        $0.add(rule: RuleRequired())
    }

    private let passwordRow = PasswordRow() {
        $0.title = "Password".localize()
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Private Server".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Connect".localize(), style: .done, target: self,
            action: #selector(connect))

        urlRow.value = conf?.url
        userNameRow.value = conf?.username
        passwordRow.value = conf?.password

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
        let conf = self.conf ?? ServerConfig()

        conf.url = urlRow.value
        conf.username = userNameRow.value
        conf.password = passwordRow.value

        Db.newConnection()?.asyncReadWrite() { transaction in
            transaction.setObject(conf, forKey: (conf.url?.absoluteString)!,
                                  inCollection: ServerConfig.COLLECTION)
        }

        navigationController?.popViewController(animated: true)
    }


    // MARK: Private Methods

    private func enableConnect() {
        navigationItem.rightBarButtonItem?.isEnabled = urlRow.isValid
            && userNameRow.isValid && passwordRow.isValid
    }
}
