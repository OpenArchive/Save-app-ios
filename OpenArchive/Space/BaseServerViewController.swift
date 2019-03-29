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
}
