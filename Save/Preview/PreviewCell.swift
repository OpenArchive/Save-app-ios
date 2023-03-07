//
//  PreviewCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol PreviewCellDelegate: AnyObject {
    func edit(_ asset: Asset, _ directEdit: DarkroomViewController.DirectEdit?)
}

class PreviewCell: BaseCell {

    override class var reuseId: String {
        return  "previewCell"
    }

    override class var height: CGFloat {
        return 240
    }

    private lazy var selectedView = SelectedView()

    @IBOutlet weak var previewImg: UIImageView!
    @IBOutlet weak var tagBt: UIButton!
    @IBOutlet weak var locationBt: UIButton!
    @IBOutlet weak var notesBt: UIButton!
    @IBOutlet weak var flagBt: UIButton!

    @IBOutlet weak var movieIndicator: MovieIndicator!

    var asset: Asset? {
        didSet {
            previewImg.image = asset?.getThumbnail()
            tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)
            locationBt.isSelected = !(asset?.location?.isEmpty ?? true)
            notesBt.isSelected = !(asset?.notes?.isEmpty ?? true)
            flagBt.isSelected = asset?.flagged ?? false
            movieIndicator.isHidden = !(asset?.isAv ?? false)
            movieIndicator.set(duration: asset?.duration)
        }
    }

    weak var delegate: PreviewCellDelegate?

    override var isSelected: Bool {
        didSet {
            if isSelected {
                selectedView.addToSuperview(self.contentView)
            }
            else {
                selectedView.removeFromSuperview()
            }
        }
    }


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

            asset.store()

            FlagInfoAlert.presentIfNeeded()
        }
    }
}
