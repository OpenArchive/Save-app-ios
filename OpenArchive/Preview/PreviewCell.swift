//
//  PreviewCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol PreviewCellDelegate: class {
    func edit(_ asset: Asset, _ directEdit: EditViewController.DirectEdit?)
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
    @IBOutlet weak var notesBt: UIButton!
    @IBOutlet weak var flagBt: UIButton!

    var asset: Asset? {
        didSet {
            previewImg.image = asset?.getThumbnail()
            tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)
            locationBt.isSelected = !(asset?.location?.isEmpty ?? true)
            notesBt.isSelected = !(asset?.notes?.isEmpty ?? true)
            flagBt.isSelected = asset?.flagged ?? false
        }
    }

    weak var delegate: PreviewCellDelegate?


    // MARK: Actions

    @IBAction func edit(_ sender: UIButton) {
        if let asset = asset {
            if sender == tagBt {
                delegate?.edit(asset, .description)
            }
            else if sender == locationBt {
                delegate?.edit(asset, .location)
            }
            else {
                delegate?.edit(asset, .notes)
            }
        }
    }

    @IBAction func flag() {
        if let asset = asset {
            asset.flagged = !asset.flagged
            flagBt.isSelected = asset.flagged

            Db.writeConn?.asyncReadWrite { transaction in
                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }

            FlagInfoAlert.presentIfNeeded()
        }
    }
}
