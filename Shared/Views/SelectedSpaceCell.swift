//
//  SelectedSpaceCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SelectedSpaceCell: BaseCell {

    override class var height: CGFloat {
        return 86
    }

    @IBOutlet weak var favIcon: UIImageView!

    @IBOutlet weak var serverNameLb: UILabel! {
        didSet {
            serverNameLb.font = .montserrat(forTextStyle: .title1, with: .traitBold)
        }
    }

    @IBOutlet weak var userNameLb: UILabel!

    var space: Space? {
        didSet {
            favIcon.image = space?.favIcon
            serverNameLb.text = space?.prettyName

            if let name = space?.authorName, !name.isEmpty {
                userNameLb.text = name
            }
            else if let email = (space as? DropboxSpace)?.email, !email.isEmpty {
                userNameLb.text = email
            }
            else {
                userNameLb.text = space?.username
            }
        }
    }
}
