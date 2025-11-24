//
//  PreviewCell.swift
//  Save
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class PreviewCell: UICollectionViewCell {

    @IBOutlet weak var fileImage: UIImageView!
    @IBOutlet weak var filename: UILabel!
    @IBOutlet weak var defaultFileType: UIView!
    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return "previewCell"
    }

    class var height: CGFloat {
        return 240
    }

    private lazy var selectedView = SelectedView()
    
    private var currentAssetId: String?

    @IBOutlet weak var previewImg: UIImageView!

    @IBOutlet weak var movieIndicator: MovieIndicator!

    var asset: Asset? {
        didSet {
            configureCell()
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset to default state to prevent showing old images
        previewImg.image = UIImage(named: "NoImage")
        movieIndicator.isHidden = true
        defaultFileType.isHidden = true
        currentAssetId = nil
    }
    
    private func configureCell() {
        guard let asset = asset else {
            previewImg.image = UIImage(named: "NoImage")
            defaultFileType.isHidden = true
            movieIndicator.isHidden = true
            return
        }
        
        // Store the current asset ID to prevent race conditions
        currentAssetId = asset.id
        
        // Set placeholder immediately
        previewImg.image = UIImage(named: "NoImage")
        defaultFileType.isHidden = true
        if asset.hasThumbnail() == true {
            previewImg.isHidden = false
            defaultFileType.isHidden = true
            asset.getThumbnailAsync { [weak self] thumbnail in
                guard self?.currentAssetId == asset.id else { return }
                self?.previewImg.image = thumbnail
            }
            movieIndicator.isHidden = !(asset.isAv)
            movieIndicator.set(duration: asset.duration)
        }
        else{
            defaultFileType.isHidden = false
            previewImg.isHidden = true
            movieIndicator.isHidden = true
            filename.text = asset.filename
            fileImage.image = UIImage(named: asset.getFileType().placeholder)
        }
    }
}
