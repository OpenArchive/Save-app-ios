//
//  UploadCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import DownloadButton

protocol UploadCellDelegate {
    func progressTapped(_ upload: Upload, _ button: PKDownloadButton)
}

class UploadCell: BaseCell, PKDownloadButtonDelegate {

    override class var reuseId: String {
        return "uploadCell"
    }

    @IBOutlet weak var progress: PKDownloadButton! {
        didSet {
            let icon = UIImage(named: "ic_up")

            progress.startDownloadButton.setTitle(nil, for: .normal)
            progress.startDownloadButton.setAttributedTitle(nil, for: .normal)
            progress.startDownloadButton.setImage(icon?.withRenderingMode(.alwaysTemplate), for: .normal)
            progress.startDownloadButton.setBackgroundImage(
                UIImage.buttonBackground(with: UIColor.accent)?
                    .resizableImage(withCapInsets: UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)),
                for: .normal)
            progress.startDownloadButton.setTitle(nil, for: .highlighted)
            progress.startDownloadButton.setAttributedTitle(nil, for: .highlighted)
            progress.startDownloadButton.setImage(icon, for: .highlighted)
            progress.startDownloadButton.setBackgroundImage(
                UIImage.highlitedButtonBackground(with: UIColor.accent),
                for: .highlighted)

            progress.stopDownloadButton.stopButton.setImage(
                UIImage.stop(ofSize: progress.stopDownloadButton.stopButtonWidth, color: UIColor.accent),
                for: .normal)
        }
    }
    
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var nameLb: UILabel!

    weak var upload: Upload? {
        didSet {
            progress.state = upload?.state ?? .pending
            progress.stopDownloadButton.progress = CGFloat(upload?.progress ?? 0)
            thumbnail.image = upload?.thumbnail
            nameLb.text = upload?.filename
        }
    }

    var delegate: UploadCellDelegate?


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        if let upload = upload {
            delegate?.progressTapped(upload, downloadButton)
        }
    }
}
