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

    var space: WebDavSpace?

    private let nameRow = TextRow() {
        $0.title = "Name".localize()
    }

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

        nameRow.value = space?.name
        urlRow.value = space?.url
        userNameRow.value = space?.username
        passwordRow.value = space?.password

        form
            +++ Section()

            <<< nameRow

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
        workingOverlay.isHidden = false

        let space = self.space ?? WebDavSpace()

        space.name = nameRow.value
        space.url = urlRow.value
        space.username = userNameRow.value
        space.password = passwordRow.value

        // Do a test request to check validity of space configuration.
        space.provider?.attributesOfItem(path: "") { file, error in
            DispatchQueue.main.async {
                self.workingOverlay.isHidden = true

                if let error = error {
                    AlertHelper.present(self, message: error.localizedDescription)
                }
                else {
                    Db.writeConn?.asyncReadWrite() { transaction in
                        transaction.setObject(space, forKey: space.id,
                                              inCollection: Space.collection)
                    }

                    self.navigationController?.popViewController(animated: true)

                    // If OnboardingViewController called us, let it know, that the
                    // user created a space successfully.
                    if let onboardingVc = self.navigationController?.topViewController as? OnboardingViewController {
                        onboardingVc.spaceCreated = true
                    }
                }
            }
        }
    }


    // MARK: Private Methods

    private func enableConnect() {
        navigationItem.rightBarButtonItem?.isEnabled = urlRow.isValid
            && userNameRow.isValid && passwordRow.isValid
    }
}
