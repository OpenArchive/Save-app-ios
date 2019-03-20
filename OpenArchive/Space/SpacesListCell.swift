//
//  SpacesListCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 26.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import AlignedCollectionViewFlowLayout

class SpacesListCell: BaseCell {

    override class var reuseId: String {
        return  "spacesListCell"
    }

    override class var height: CGFloat {
        return 54
    }

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            let alignedFlowLayout = collectionView?.collectionViewLayout as? AlignedCollectionViewFlowLayout
            alignedFlowLayout?.horizontalAlignment = .right
            alignedFlowLayout?.itemSize = CGSize(width: 32, height: 32)
            alignedFlowLayout?.minimumInteritemSpacing = 24
        }
    }
}
