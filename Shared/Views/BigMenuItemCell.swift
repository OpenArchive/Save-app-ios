//
//  MenuItemCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BigMenuItemCell: BaseCell {

    override class var height: CGFloat {
        return 100
    }

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var detailedDescription: UILabel!
}
