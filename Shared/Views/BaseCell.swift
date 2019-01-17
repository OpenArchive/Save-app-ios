//
//  BaseCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BaseCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: reuseId, bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }
}
