//
//  ProfileCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ProfileCell: BaseCell {

    override class var reuseId: String {
        return  "profileCell"
    }

    override class var height: CGFloat {
        return 163
    }

    @IBOutlet weak var avatarImg: UIImageView!
    @IBOutlet weak var aliasLb: UILabel!
    @IBOutlet weak var roleLb: UILabel!

    func set() -> ProfileCell {
        avatarImg.image = Profile.avatar ?? Profile.defaultAvatar

        aliasLb.text = Profile.alias == nil || Profile.alias!.isEmpty
            ? "Your Alias".localize()
            : Profile.alias

        roleLb.text = Profile.role == nil || Profile.role!.isEmpty
            ? "Your Role".localize()
            : Profile.role

        return self
    }
}
