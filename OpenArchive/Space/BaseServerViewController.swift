//
//  BaseServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class BaseServerViewController: FormViewController, DoneDelegate {

    var space: Space?

    var isEdit: Bool?

    let favIconRow = AvatarRow() {
        $0.disabled = true
        $0.placeholderImage = SelectedSpace.defaultFavIcon
    }

    let userNameRow = AccountRow() {
        $0.title = "User Name".localize()
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
        SelectedSpace.space = space

        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(self.space, forKey: self.space!.id,
                                  inCollection: Space.collection)
        }

        if isEdit ?? true {
            self.done()
        }
        else {
            let vc = NewProjectViewController()
            vc.delegate = self

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    
    // MARK: ConnectSpaceDelegate

    func done() {
        // Only animate, if we don't have a delegate: Too much pop animations
        // will end in the last view controller not being popped and it's also
        // too much going on in the UI.
        navigationController?.popViewController(animated: delegate == nil)

        // If ConnectSpaceViewController called us, let it know, that the
        // user created a space successfully.
        delegate?.done()
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
                        Db.writeConn?.asyncReadWrite { transaction in
                            transaction.removeObject(forKey: space.id, inCollection: Space.collection)

                            var newSelectedSpace: Space?

                            transaction.enumerateKeysAndObjects(inCollection: Space.collection) { key, object, stop in
                                if let space = object as? Space {
                                    newSelectedSpace = space
                                    stop.pointee = true
                                }
                            }

                            DispatchQueue.main.async {
                                SelectedSpace.space = newSelectedSpace
                            }

                            DispatchQueue.main.async(execute: self.goToMenu)
                        }
                })
            ])
    }

    /**
     Pop to MenuViewController or to first view controller in navigation stack.
    */
    private func goToMenu() {
        if let navVc = navigationController,
            let menuVc = navVc.viewControllers.first(where: { $0 is MenuViewController })
                ?? navVc.viewControllers.first {

            navVc.popToViewController(menuVc, animated: true)
        }
    }
}
