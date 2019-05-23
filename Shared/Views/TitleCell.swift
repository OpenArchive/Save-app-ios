//
//  TitleCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TitleCell: BaseCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    private func setup() {
        selectionStyle = .none

        if let label = self.textLabel {
            label.textColor = UIColor.accent
            label.font = UIFont(name: "Montserrat-Bold", size: 24)
            label.textAlignment = .center
        }
    }
}
