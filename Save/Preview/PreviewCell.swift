//
//  PreviewCell.swift
//  Save
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class PreviewCell: UICollectionViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return  "previewCell"
    }

    class var height: CGFloat {
        return 240
    }


    private lazy var selectedView = SelectedView()


    @IBOutlet weak var previewImg: UIImageView!

    @IBOutlet weak var movieIndicator: MovieIndicator!


    var asset: Asset? {
        didSet {
            previewImg.image = asset?.getThumbnail()
            movieIndicator.isHidden = !(asset?.isAv ?? false)
            movieIndicator.set(duration: asset?.duration)
        }
    }

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
}
