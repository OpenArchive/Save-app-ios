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
            label.minimumScaleFactor = 0.5
            label.adjustsFontSizeToFitWidth = true
            label.allowsDefaultTighteningForTruncation = true
        }
    }

    @IBOutlet weak var detailedDescription: UILabel! {
        didSet {
            detailedDescription.numberOfLines = 2
            detailedDescription.minimumScaleFactor = 0.5
            detailedDescription.adjustsFontSizeToFitWidth = true
            detailedDescription.allowsDefaultTighteningForTruncation = true
        }
    }

    func setWebDav() -> BigMenuItemCell {
        label.text = "Private (WebDAV) Server".localize()
        detailedDescription.text = "Send directly to a private server.".localize()

        return self
    }

    func setDropbox() -> BigMenuItemCell {
        label.text = "Dropbox".localize()
        detailedDescription.text = "Upload to Dropbox".localize()

        return self
    }

    func setInternetArchive() -> BigMenuItemCell {
        label.text = "Internet Archive".localize()
        detailedDescription.text = "Upload to the Internet Archive".localize()

        return self
    }
}
