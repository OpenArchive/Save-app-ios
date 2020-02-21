//
//  FolderCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

class FolderCell: BaseCell {

    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var nameLbToCenterY: NSLayoutConstraint!
    @IBOutlet weak var modifiedLb: UILabel!

    @discardableResult
    func set(folder: BrowseViewController.Folder) -> FolderCell {
        nameLb.text = folder.name

        if let modified = folder.modifiedDate {
            modifiedLb.text = Formatters.date.string(from: modified)
            modifiedLb.isHidden = false
            nameLbToCenterY.constant = 0
        }
        else {
            modifiedLb.isHidden = true
            nameLbToCenterY.constant = 10
        }

        return self
    }
}
