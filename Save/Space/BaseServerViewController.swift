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
        $0.title = NSLocalizedString("User Name", comment: "")
        $0.placeholder = NSLocalizedString("Required", comment: "")
        $0.cell.textField.accessibilityIdentifier = "tfUsername"
        $0.add(rule: RuleRequired())
    }

    let removeRow = ButtonRow() {
        $0.title = NSLocalizedString("Remove from App", comment: "")
    }
    .cellUpdate({ cell, _ in
        cell.textLabel?.textColor = .systemRed
    })

    var discloseButton: UIButton {
        let image = UIImage(named: "eye")

        let button = UIButton(type: .custom)
        button.setImage(image)
        button.frame = CGRect(origin: .zero, size: image?.size ?? CGSize(width: 21, height: 21))
        button.addTarget(self, action: #selector(discloseButtonTapped), for: .touchUpInside)

        return button
    }


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

    @objc
    private func discloseButtonTapped(_ sender: UIButton) {
        if let cell = sender.superview as? PasswordCell {
            let wasSecure = cell.textField?.isSecureTextEntry ?? true

            cell.textField?.isSecureTextEntry = !wasSecure

            sender.setImage(UIImage(named: wasSecure ? "eye.slash" : "eye"))
        }
    }

    /**
     Shows an alert and removes this space from the database, if user says so.
    */
    private func removeSpace(cell: ButtonCellOf<String>, row: ButtonRow) {
        guard let space = self.space else {
            return
        }

        AlertHelper.present(
            self, message: NSLocalizedString("This will remove the asset history for that space, too!", comment: ""),
            title: NSLocalizedString("Remove Space", comment: ""),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.destructiveAction(
                    NSLocalizedString("Remove Space", comment: ""),
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
