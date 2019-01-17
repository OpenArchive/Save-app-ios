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

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Edit Profile".localize()

        form
            +++ Section()

            <<< AvatarRow()

            <<< NameRow() {
                $0.title = "Your Alias".localize()
                $0.value = Profile.alias
            }
            .onChange() { row in
                Profile.alias = row.value
            }

            <<< NameRow() {
                $0.cell.textField.textContentType = .jobTitle
                $0.title = "Your Role".localize()
                $0.value = Profile.role
            }
            .onChange() { row in
                Profile.role = row.value
            }
    }
}
