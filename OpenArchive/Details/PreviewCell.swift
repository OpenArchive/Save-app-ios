//
//  PreviewCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol PreviewCellDelegate: class {
    func editPeople(_ asset: Asset)

    func editLocation(_ asset: Asset)
}

class PreviewCell: BaseCell {

    override class var reuseId: String {
        return  "previewCell"
    }

    override class var height: CGFloat {
        return 240
    }

    @IBOutlet weak var previewImg: UIImageView!
    @IBOutlet weak var tagBt: UIButton!
    @IBOutlet weak var locationBt: UIButton!
    @IBOutlet weak var flagBt: UIButton!

    var asset: Asset? {
        didSet {
            previewImg.image = asset?.getThumbnail()
            tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)
            locationBt.isSelected = !(asset?.location?.isEmpty ?? true)
            flagBt.isSelected = false
        }
    }

    weak var delegate: PreviewCellDelegate?


    // MARK: Actions

    @IBAction func edit(_ sender: UIButton) {
        if let asset = asset {
            if sender == tagBt {
                delegate?.editPeople(asset)
            }
            else {
                delegate?.editLocation(asset)
            }
        }
    }

    @IBAction func flag() {
        // TODO
    }
}
