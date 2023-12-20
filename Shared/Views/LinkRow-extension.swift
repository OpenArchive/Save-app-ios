//
//  LinkRow-extension.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
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
        textLabel?.text = row.title

        textLabel?.textColor = .tertiaryLabel
    }
}


final class LinkRow: Row<LinkCell>, RowType {

    required public init(tag: String?) {
        super.init(tag: tag)

        disabled = true
    }

    override func customDidSelect() {
        // Do nothing. We cannot open links in a Share Extension.
    }
}
