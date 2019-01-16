//
//  MenuItemCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MenuItemCell: BaseCell {

    static let height: CGFloat = 44.0

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addIndicator: UILabel!

    func set(_ label: String, isPlaceholder: Bool = false) {
        self.label.text = label
        self.label.textColor = isPlaceholder ? UIColor.lightGray : UIColor.darkText

        addIndicator.isHidden = !isPlaceholder
    }
}
