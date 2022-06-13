//
//  MenuItemCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BigMenuItemCell: BaseCell {

    override class var height: CGFloat {
        return 100
    }

    @IBOutlet weak var label: UILabel! {
        didSet {
            label.font = .montserrat(forTextStyle: .headline)
        }
    }

    @IBOutlet weak var detailedDescription: UILabel!

    func setWebDav() -> BigMenuItemCell {
        label.text = NSLocalizedString("Private (WebDAV) Server", comment: "")
        detailedDescription.text = NSLocalizedString("Send directly to a private server.", comment: "")

        return self
    }

    func setDropbox() -> BigMenuItemCell {
        label.text = NSLocalizedString("Dropbox", comment: "")
        detailedDescription.text = NSLocalizedString("Upload to Dropbox", comment: "")

        return self
    }

    func setInternetArchive() -> BigMenuItemCell {
        label.text = NSLocalizedString("Internet Archive", comment: "")
        detailedDescription.text = NSLocalizedString("Upload to the Internet Archive", comment: "")

        return self
    }
}
