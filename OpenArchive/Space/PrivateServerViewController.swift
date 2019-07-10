//
//  PrivateServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import FavIcon
import YapDatabase

class PrivateServerViewController: BaseServerViewController {

    private let nameRow = TextRow() {
        $0.title = "Server Name".localize()
        $0.placeholder = "Optional".localize()
    }

    private let urlRow = URLRow() {
        $0.title = "Server URL".localize()
        $0.placeholder = "Required".localize()
        $0.add(rule: RuleRequired())
        $0.formatter = Formatters.URLFormatter()
    }

    private let passwordRow = PasswordRow() {
        $0.title = "Password".localize()
        $0.placeholder = "Required".localize()
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Private Server".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: space != nil ? "Done".localize() : "Connect".localize(),
            style: .done, target: self,
            action: #selector(connect))

        favIconRow.value = space?.favIcon
        nameRow.value = space?.name
        urlRow.value = space?.url
        userNameRow.value = space?.username
        passwordRow.value = space?.password

        form
            +++ Section()

            <<< favIconRow

            <<< nameRow

            <<< urlRow.cellUpdate() { _, row in
                self.acquireFavIcon()
                self.enableConnect()
            }

            <<< userNameRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            <<< passwordRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            // To get another divider after the last row.
            <<< LabelRow()

        if space != nil {
            form
                +++ removeRow
        }

        form.validate()
        enableConnect()
    }


    // MARK: Actions

    @objc override func connect() {
        workingOverlay.isHidden = false

        if space == nil {
            space = WebDavSpace()
            isEdit = false
        }
        else if isEdit == nil {
            isEdit = true
        }

        space?.name = nameRow.value
        space?.url = Formatters.URLFormatter.fix(url: urlRow.value)
        space?.favIcon = favIconRow.value
        space?.username = userNameRow.value
        space?.password = passwordRow.value

        // Do a test request to check validity of space configuration.
        (space as? WebDavSpace)?.provider?.attributesOfItem(path: "") { file, error in
            DispatchQueue.main.async {
                self.workingOverlay.isHidden = true

                if let error = error {
                    AlertHelper.present(self, message: error.localizedDescription)
                }
                else {
                    super.connect()
                }
            }
        }
    }


    // MARK: Private Methods

    private func acquireFavIcon() {
        if let baseUrl = Formatters.URLFormatter.fix(url: urlRow.value, baseOnly: true) {

            try! FavIcon.downloadPreferred(baseUrl) { result in
                if case let .success(image) = result {
                    self.favIconRow.value = image
                    self.favIconRow.reload()
                }
            }
        }
    }

    private func enableConnect() {
        navigationItem.rightBarButtonItem?.isEnabled = urlRow.isValid
            && userNameRow.isValid && passwordRow.isValid
    }
}
