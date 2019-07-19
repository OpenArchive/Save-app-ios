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
            accessoryView = nil
            self.accessoryType = .none

        case .disclosureIndicator:
            accessoryView = nil
            self.accessoryType = .disclosureIndicator

        case .detailDisclosureButton:
            accessoryView = nil
            self.accessoryType = .detailDisclosureButton

        case .checkmark:
            accessoryView = nil
            self.accessoryType = .checkmark

        case .detailButton:
            accessoryView = nil
            self.accessoryType = .detailButton

        case .addIndicator:
            self.accessoryType = .none
            let add = UILabel()
            add.font = UIFont.systemFont(ofSize: 22)
            add.textColor = UIColor.lightGray
            add.text = "+"
            add.sizeToFit()
            accessoryView = add
        }

        return self
    }

    @discardableResult
    func set(_ text: String, isPlaceholder: Bool = false) -> MenuItemCell {
        return set(text, textColor: isPlaceholder ? .lightGray : .darkText,
                   accessoryType: isPlaceholder ? .addIndicator : .none)
    }

    @discardableResult
    func set(_ error: Error) -> MenuItemCell {
        return set(error.friendlyMessage, textColor: .red)
    }
}
