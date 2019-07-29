//
//  BaseServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class BaseServerViewController: FormViewController {

    var space: Space?

    var isEdit: Bool?

    let favIconRow = AvatarRow() {
        $0.disabled = true
        $0.placeholderImage = SelectedSpace.defaultFavIcon
    }

    let userNameRow = AccountRow() {
        $0.title = "User Name".localize()
        $0.placeholder = "Required".localize()
        $0.cell.textField.accessibilityIdentifier = "tfUsername"
        $0.add(rule: RuleRequired())
    }

    let removeRow = ButtonRow() {
        $0.title = "Remove from App".localize()
    }
    .cellUpdate({ cell, _ in
        cell.textLabel?.textColor = UIColor.red
    })

    override init() {
        super.init()

        removeRow.onCellSelection(removeSpace)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    @objc func connect() {
        SelectedSpace.space = self.space

        Db.writeConn?.asyncReadWrite() { transaction in
            SelectedSpace.store(transaction)

            transaction.setObject(self.space, forKey: self.space!.id,
                                  inCollection: Space.collection)
        }

        if isEdit ?? true {
            if let rootVc = navigationController?.viewControllers.first {
                navigationController?.setViewControllers([rootVc], animated: true)
            }
        }
        else {
            navigationController?.setViewControllers([AddProjectViewController()], animated: true)
        }
    }


    // MARK: Private Methods

    /**
     Shows an alert and removes this space from the database, if user says so.
    */
    private func removeSpace(cell: ButtonCellOf<String>, row: ButtonRow) {
        guard let space = self.space else {
            return
        }

        AlertHelper.present(
            self, message: "This will remove the asset history for that space, too!".localize(),
            title: "Remove Space".localize(),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.destructiveAction(
                    "Remove Space".localize(),
                    handler: { action in
                        Db.writeConn?.readWrite { transaction in
                            transaction.removeObject(forKey: space.id, inCollection: Space.collection)

                            SelectedSpace.space = nil
                            SelectedSpace.store(transaction)

                            DispatchQueue.main.async(execute: self.goToNext)
                        }
                })
            ])
    }

    /**
     Pop to MenuViewController or to ConnectSpaceViewController, depending on
     if we still have a space.
    */
    private func goToNext() {
        if SelectedSpace.available {
            navigationController?.popToRootViewController(animated: true)
            return
        }

        (navigationController as? MenuNavigationController)?.setRoot()
    }
}
