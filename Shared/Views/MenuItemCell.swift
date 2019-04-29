//
//  MenuItemCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MenuItemCell: BaseCell {

    enum AccType: Int {
        case none // don't show any accessory view

        case disclosureIndicator // regular chevron. doesn't track

        case detailDisclosureButton // info button w/ chevron. tracks

        case checkmark // checkmark. doesn't track

        case detailButton // info button. tracks

        case addIndicator
    }

    @IBOutlet weak var label: UILabel!

    func set(_ text: String = "", textColor: UIColor = .darkText, accessoryType: AccType = .none) -> MenuItemCell {

        label.text = text
        label.textColor = textColor

        switch accessoryType {
        case .none:
            self.accessoryType = .none
        case .disclosureIndicator:
            self.accessoryType = .disclosureIndicator
        case .detailDisclosureButton:
            self.accessoryType = .detailDisclosureButton
        case .checkmark:
            self.accessoryType = .checkmark
        case .detailButton:
            self.accessoryType = .detailButton
        case .addIndicator:
            let add = UILabel()
            add.font = UIFont.systemFont(ofSize: 22)
            add.textColor = UIColor.lightGray
            add.text = "+"
            add.sizeToFit()
            accessoryView = add
        }

        return self
    }

    func set(_ text: String, isPlaceholder: Bool = false) -> MenuItemCell {
        return set(text, textColor: isPlaceholder ? UIColor.lightGray : UIColor.darkText,
                   accessoryType: isPlaceholder ? .addIndicator : .none)
    }

    func set(_ error: Error) -> MenuItemCell {
        return set(error.localizedDescription, textColor: UIColor.red)
    }
}
