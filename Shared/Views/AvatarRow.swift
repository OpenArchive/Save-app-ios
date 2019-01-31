//
//  AvatarRow.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import ImageRow

public final class AvatarCell: PushSelectorCell<UIImage> {

    @IBOutlet weak var avatar: UIImageView!

    public override func update() {
        super.update()

        accessoryType = .none
        editingAccessoryView = .none

        avatar.image = row.value ?? (row as? ImageRowProtocol)?.placeholderImage
    }
}

final class AvatarRow: _ImageRow<AvatarCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<AvatarCell>(nibName: String(describing: AvatarCell.self))
    }
}
