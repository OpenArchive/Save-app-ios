//
//  EditProfileViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class EditProfileViewController: FormViewController {

    var space: Space?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Profile".localize()

        space = SelectedSpace.space

        form
            +++ Section()

            <<< NameRow() {
                $0.title = "Name".localize()
                $0.placeholder = "Optional".localize()
                $0.value = space?.authorName
            }
            .onChange() { row in
                self.space?.authorName = row.value
            }

            <<< NameRow() {
                $0.cell.textField.textContentType = .jobTitle
                $0.title = "Role".localize()
                $0.placeholder = "Optional".localize()
                $0.value = space?.authorRole
            }
            .onChange() { row in
                self.space?.authorRole = row.value
            }

            <<< TextRow() {
                $0.title = "Other Info".localize()
                $0.placeholder = "Optional".localize()
                $0.value = space?.authorOther
            }
            .onChange() { row in
                self.space?.authorOther = row.value
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        Db.writeConn?.asyncReadWrite { transaction in
            if let space = self.space {
                transaction.setObject(space, forKey: space.id, inCollection: Space.collection)
            }
        }

        super.viewWillDisappear(animated)
    }
}
