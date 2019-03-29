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
    @IBOutlet weak var modifiedLb: UILabel!

    func set(folder: FileObject) -> FolderCell {
        nameLb.text = folder.name

        if let modified = folder.modifiedDate ?? folder.creationDate {
            modifiedLb.text = Formatters.date.string(from: modified)
        }
        else {
            modifiedLb.text = ""
        }

        return self
    }
}
