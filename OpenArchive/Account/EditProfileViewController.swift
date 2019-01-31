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

            <<< AvatarRow() {
                $0.allowEditor = true
                $0.placeholderImage = Profile.defaultAvatar
                $0.sourceTypes = [.Camera, .PhotoLibrary]
                $0.useEditedImage = true
                $0.value = Profile.avatar
            }
            .onChange() { row in
                Profile.avatar = row.value
            }

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
