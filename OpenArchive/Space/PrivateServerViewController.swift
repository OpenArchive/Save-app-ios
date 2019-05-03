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
        $0.title = "Name".localize()
    }

    private let urlRow = URLRow() {
        $0.title = "Server URL".localize()
        $0.add(rule: RuleRequired())
        $0.formatter = Formatters.URLFormatter()
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

        if space != nil {
            form
            +++ ButtonRow() {
                $0.title = "Remove".localize()
            }
            .cellUpdate({ cell, _ in
                cell.textLabel?.textColor = UIColor.red
            })
            .onCellSelection(removeSpace)
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

    private func removeSpace(cell: ButtonCellOf<String>, row: ButtonRow) {
        guard let space = self.space else {
            return
        }

        AlertHelper.present(
            self, message: "This will remove all assets stored in that space, too!".localize(),
            title: "Remove Space".localize(),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.destructiveAction(
                    "Remove Space".localize(),
                    handler: { action in
                        Db.writeConn?.asyncReadWrite { transaction in
                            transaction.removeObject(forKey: space.id, inCollection: Space.collection)

                            SelectedSpace.id = nil

                            transaction.enumerateKeys(inCollection: Space.collection) { key, stop in
                                SelectedSpace.id = key

                                stop.pointee = true
                            }

                            DispatchQueue.main.async(execute: self.goToMenu)
                        }
                })
            ])
    }

    private func goToMenu() {
        if let navVc = navigationController,
            let menuVc = navVc.viewControllers.first(where: { $0 is MenuViewController })
            ?? navVc.viewControllers.first {

            navVc.popToViewController(menuVc, animated: true)
        }
    }
}
