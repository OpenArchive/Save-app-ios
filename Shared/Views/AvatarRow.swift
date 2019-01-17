//
//  AvatarRow.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class AvatarCell: Cell<UIImage>, CellType {
    @IBOutlet weak var avatar: UIImageView!

    @IBAction func select() {
        print("[\(String(describing: type(of: self)))]#select")
    }
}

final class AvatarRow: Row<AvatarCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<AvatarCell>(nibName: String(describing: AvatarCell.self))
    }
}
