//
//  AssetCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import DownloadButton

class AssetCell: BaseCell, PKDownloadButtonDelegate {

    override class var reuseId: String {
        return "assetCell"
    }

    @IBOutlet weak var progress: PKDownloadButton! {
        didSet {
            progress.delegate = self
        }
    }
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var nameLb: UILabel!

    var asset: Asset? {
        didSet {
            progress.state = asset?.isUploaded ?? false ? .downloaded : .downloading
            thumbnail.image = asset?.getThumbnail()
            nameLb.text = asset?.filename
        }
    }


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        print("[\(String(describing: type(of: self)))]#downloadButtonTapped state=\(state)")
    }
}
