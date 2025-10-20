//
//  SpacesListCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 26.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SpacesListCell: BaseCell {

    override class var height: CGFloat {
        return 54
    }

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.scrollDirection = .horizontal
            flowLayout.itemSize = CGSize(width: 32, height: 32)
            flowLayout.minimumInteritemSpacing = 24
            flowLayout.minimumLineSpacing = 24
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            
            collectionView?.collectionViewLayout = flowLayout
            collectionView?.semanticContentAttribute = .forceRightToLeft
        }
    }
}
