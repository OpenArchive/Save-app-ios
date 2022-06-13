//
//  TitleCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TitleCell: BaseCell {

    class var fullHeight: CGFloat {
        return 100
    }

    @IBOutlet weak var title: UILabel! {
        didSet {
            title.font = .montserrat(forTextStyle: .title1)
        }
    }

    @IBOutlet weak var detailedDescription: UILabel!

    func set(_ title: String, _ desc: String? = nil) -> TitleCell {
        self.title.text = title

        if let desc = desc {
            detailedDescription.isHidden = false
            detailedDescription.text = desc
        }
        else {
            detailedDescription.isHidden = true
        }

        return self
    }
}
