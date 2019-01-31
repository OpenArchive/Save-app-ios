//
//  MenuItemCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MenuItemCell: BaseCell {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addIndicator: UILabel!

    func set(_ text: String = "", _ textColor: UIColor = UIColor.darkText,
             _ indicatorHidden: Bool = true) -> MenuItemCell {

        self.label.text = text
        self.label.textColor = textColor

        addIndicator.isHidden = indicatorHidden

        return self
    }

    func set(_ text: String, isPlaceholder: Bool = false) -> MenuItemCell {
        return set(text, isPlaceholder ? UIColor.lightGray : UIColor.darkText, !isPlaceholder)
    }

    func set(_ error: Error) -> MenuItemCell {
        return set(error.localizedDescription, UIColor.red)
    }
}
