//
//  ImageCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ImageCell: UICollectionViewCell {

    static let reuseId = "imageCell"

    private var blurView: UIVisualEffectView?
    
    @IBOutlet var imgView: UIImageView!

    private lazy var selectedView = SelectedView()

    var highlightNonUploaded = true

    var asset: Asset? {
        didSet {
            self.imgView.image = asset?.getThumbnail()

            if highlightNonUploaded && !(asset?.isUploaded ?? false) && !UIAccessibility.isReduceTransparencyEnabled {
                if blurView == nil {
                    blurView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
                    blurView?.alpha = 0.35
                    blurView?.frame = imgView.bounds
                    blurView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                }

                imgView.addSubview(blurView!)
            }
            else {
                blurView?.removeFromSuperview()
            }
        }
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                selectedView.addToSuperview(self)
            }
            else {
                selectedView.removeFromSuperview()
            }
        }
    }
}
