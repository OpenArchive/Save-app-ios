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
import FavIcon

class PrivateServerViewController: FormViewController {

    var space: WebDavSpace?

    private let favIconRow = AvatarRow() {
        $0.disabled = true
        $0.placeholderImage = SelectedSpace.defaultFavIcon
    }

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

    @objc func connect() {
        workingOverlay.isHidden = false

        let space = self.space ?? WebDavSpace()

        space.name = nameRow.value
        space.url = urlRow.value
        space.favIcon = favIconRow.value
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
                        SelectedSpace.space = space
                    }

                    self.navigationController?.popViewController(animated: true)

                    // If ConnectSpaceViewController called us, let it know, that the
                    // user created a space successfully.
                    if let onboardingVc = self.navigationController?.topViewController as? ConnectSpaceViewController {
                        onboardingVc.spaceCreated = true
                    }
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
