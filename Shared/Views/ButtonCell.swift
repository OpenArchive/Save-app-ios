//
//  ButtonCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ButtonCell: BaseCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    private var label = UILabel()
    override var textLabel: UILabel? {
        get {
            return label
        }
        set {
            if let newValue = newValue {
                label = newValue
            }
        }
    }

    private func setup() {
        selectionStyle = .none

        label.textColor = UIColor.accent
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        label.layer.borderWidth = 2
        label.layer.borderColor = UIColor.accent.cgColor
        label.layer.cornerRadius = ButtonCell.height / 2
        label.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(label)

        label.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5).isActive = true
        label.heightAnchor.constraint(equalToConstant: ButtonCell.height).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }
}
