//
//  SelectedSpaceCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SelectedSpaceCell: BaseCell {

    override class var reuseId: String {
        return  "selectedSpaceCell"
    }

    override class var height: CGFloat {
        return 163
    }

    @IBOutlet weak var favIcon: UIImageView!
    @IBOutlet weak var serverNameLb: UILabel!
    @IBOutlet weak var userNameLb: UILabel!

    var space: Space? {
        didSet {
            favIcon.image = space?.favIcon
            serverNameLb.text = space?.prettyName
            userNameLb.text = space?.authorName ?? space?.username
        }
    }
}
