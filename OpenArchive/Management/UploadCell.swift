//
//  UploadCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import DownloadButton

class UploadCell: BaseCell, PKDownloadButtonDelegate {

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

    var upload: Upload? {
        didSet {
            progress.state = upload?.paused ?? true
                ? .pending
                : upload?.isUploaded ?? false ? .downloaded : .downloading
            progress.stopDownloadButton.progress = CGFloat(upload?.progress ?? 0)
            thumbnail.image = upload?.thumbnail
            nameLb.text = upload?.filename
        }
    }


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        print("[\(String(describing: type(of: self)))]#downloadButtonTapped state=\(state)")
    }
}
