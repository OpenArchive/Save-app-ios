//
//  SpaceCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SpaceCell: UICollectionViewCell {

    @IBOutlet var favIcon: UIImageView!

    var space: Space? {
        didSet {
            favIcon.image = space?.favIcon
            favIcon.contentMode = .scaleAspectFit
            favIcon.layer.borderWidth = 0
            favIcon.layer.borderColor = UIColor.clear.cgColor
            favIcon.layer.cornerRadius = favIcon.frame.width / 2
        }
    }

    func setAdd() {
        space = nil
        favIcon.contentMode = .center
        favIcon.layer.borderWidth = 1
        favIcon.layer.borderColor = UIColor.accent.cgColor
        favIcon.layer.cornerRadius = favIcon.frame.width / 2
        favIcon.image = UIImage(named: "ic_add")
    }
}
