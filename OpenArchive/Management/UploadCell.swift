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

    func showError(_ upload: Upload)
}

class UploadCell: BaseCell, PKDownloadButtonDelegate {

    override class var reuseId: String {
        return "uploadCell"
    }

    override class var height: CGFloat {
        return 64
    }

    class func style(_ button: PKDownloadButton) {
        let icon = UIImage(named: "ic_up")

        button.startDownloadButton.setTitle(nil, for: .normal)
        button.startDownloadButton.setAttributedTitle(nil, for: .normal)
        button.startDownloadButton.setImage(icon?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.startDownloadButton.setBackgroundImage(
            UIImage.buttonBackground(with: .accent)?
                .resizableImage(withCapInsets: UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)),
            for: .normal)
        button.startDownloadButton.setTitle(nil, for: .highlighted)
        button.startDownloadButton.setAttributedTitle(nil, for: .highlighted)
        button.startDownloadButton.setImage(icon, for: .highlighted)
        button.startDownloadButton.setBackgroundImage(
            UIImage.highlitedButtonBackground(with: .accent),
            for: .highlighted)

        button.stopDownloadButton.stopButton.setImage(
            UIImage.stop(ofSize: button.stopDownloadButton.stopButtonWidth, color: .accent),
            for: .normal)
    }

    @IBOutlet weak var progress: PKDownloadButton! {
        didSet {
            UploadCell.style(progress)
        }
    }
    
    @IBOutlet weak var errorBt: UIButton!
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var sizeLb: UILabel!
    
    weak var upload: Upload? {
        didSet {
            let total = upload?.asset?.filesize ?? 0
            let progressValue = upload?.progress ?? 0
            // The first 10% are for folder creation and metadata file upload, so correct for these.
            let done = Double(total) * (progressValue - 0.1) / 0.9

            progress.isHidden = upload?.error != nil
            progress.state = upload?.state ?? .pending
            progress.stopDownloadButton.progress = CGFloat(progressValue)
            errorBt.isHidden = upload?.error == nil
            thumbnail.image = upload?.thumbnail
            nameLb.text = upload?.filename

            sizeLb.text = Formatters.formatByteCount(total)

            if done > 0 {
                // \u{2191} is up arrow
                sizeLb.text = (sizeLb.text ?? "") + " – \u{2191}\(Formatters.formatByteCount(Int64(done)))"
            }
        }
    }

    var delegate: UploadCellDelegate?


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton, currentState state: PKDownloadButtonState) {
        if let upload = upload {
            delegate?.progressTapped(upload, downloadButton)
        }
    }

    @IBAction func showError() {
        if let upload = upload {
            delegate?.showError(upload)
        }
    }
}
