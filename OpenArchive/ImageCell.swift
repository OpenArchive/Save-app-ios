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
    
    @IBOutlet var imgView: UIImageView!

    var asset: Asset? {
        didSet {
            self.imgView.image = asset?.getThumbnail()
        }
    }
}
