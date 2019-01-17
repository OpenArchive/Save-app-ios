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

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Private Server".localize()

        form
            +++ Section()

            <<< URLRow() {
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
            .onChange() { row in
                WebDavServer.baseUrl = row.value?.absoluteString
                WebDavServer.subfolders = nil
            }

            <<< AccountRow() {
                $0.title = "User Name".localize()
                $0.value = WebDavServer.username
                $0.add(rule: RuleRequired())
            }
            .onChange() { row in
                WebDavServer.username = row.value
            }

            <<< PasswordRow() {
                $0.title = "Password".localize()
                $0.value = WebDavServer.password
                $0.add(rule: RuleRequired())
            }
            .onChange() { row in
                WebDavServer.password = row.value
            }
    }
}
