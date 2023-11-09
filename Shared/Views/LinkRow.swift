//
//  LinkRow.swift
//  Save
//
//  Created by Benjamin Erhart on 09.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Eureka

open class LinkCell: Cell<URL>, CellType {

    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func setup() {
        super.setup()

        selectionStyle = .none
    }

    open override func update() {
        textLabel?.attributedText = row.title?.underlined

        textLabel?.textColor = row.isDisabled ? .tertiaryLabel : .accent
    }
}


final class LinkRow: Row<LinkCell>, RowType {

    required public init(tag: String?) {
        super.init(tag: tag)
    }

    override func customDidSelect() {
        if !isDisabled, let value = value {
            UIApplication.shared.open(value)
        }
    }
}
