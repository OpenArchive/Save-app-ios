//
//  ProfileCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ProfileCell: BaseCell {

    @IBOutlet weak var avatarImg: UIImageView!
    @IBOutlet weak var aliasLb: UILabel!
    @IBOutlet weak var roleLb: UILabel!

    func set() {
        aliasLb.text = Profile.alias
        roleLb.text = Profile.role
    }
}
