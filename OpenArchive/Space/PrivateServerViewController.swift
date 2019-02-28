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

class PrivateServerViewController: BaseServerViewController {

    private let nameRow = TextRow() {
        $0.title = "Name".localize()
    }

    private let urlRow = URLRow() {
        $0.title = "Server URL".localize()
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

        favIconRow.value = space?.favIcon
        nameRow.value = space?.name
        urlRow.value = space?.url
        userNameRow.value = space?.username
        passwordRow.value = space?.password

        form
            +++ Section()

            <<< favIconRow

            <<< nameRow

            <<< urlRow.cellUpdate() { _, _ in
                self.acquireFavIcon()
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
        space?.url = urlRow.value
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
        if let url = urlRow.value,
            let host = url.host,
            let baseUrl = URL(string: "\(url.scheme ?? "https")://\(host)\(url.port == nil ? "" : ":\(url.port!)")/") {

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
