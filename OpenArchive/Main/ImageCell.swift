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

    private lazy var selectedView: UIView = {
        let view = UIView()

        view.layer.borderColor = UIColor.accent.cgColor
        view.layer.borderWidth = 10
        view.layer.cornerRadius = 15

        return view
    }()

    var asset: Asset? {
        didSet {
            self.imgView.image = asset?.getThumbnail()

            if !(asset?.isUploaded ?? false) && !UIAccessibility.isReduceTransparencyEnabled {
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
                addSubview(selectedView)
                selectedView.frame = CGRect.init(x: bounds.origin.x - 5,
                                                 y: bounds.origin.y - 5,
                                                 width: bounds.size.width + 10,
                                                 height: bounds.size.height + 10)
            }
            else {
                selectedView.removeFromSuperview()
            }
        }
    }
}
