//
//  UploadCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol UploadCellDelegate: AnyObject {
    func progressTapped(_ upload: Upload, _ button: ProgressButton)

    func showError(_ upload: Upload)
    
    func delete(_ upload: Upload,from cell: UploadCell)
}

class UploadCell: BaseCell {

    override class var reuseId: String {
        return "uploadCell"
    }

    override class var height: CGFloat {
        return 70
    }

    @IBOutlet weak var DeleteButton: UIButton!{
        didSet {
            DeleteButton.addTarget(self, action: #selector(deleteTapped), for: [])
        }
    }
    @IBOutlet weak var progress: ProgressButton!
//    {
//        didSet {
//            progress.addTarget(self, action: #selector(progressTapped))
//        }
//    }
    
    @IBOutlet weak var errorBt: UIButton!

    @IBOutlet weak var done: UIImageView!

    @IBOutlet weak var thumbnail: UIImageView!

    @IBOutlet weak var nameLb: UILabel! {
        didSet {
            nameLb.font = .montserrat(forTextStyle: .subheadline)
        }
    }

    @IBOutlet weak var sizeLb: UILabel!{
        didSet {
            sizeLb.font = .montserrat(forTextStyle: .caption1)
            sizeLb.textColor = .gray70
        }
    }
    
    weak var upload: Upload? {
        didSet {
            let progressValue = upload?.progress ?? 0

            progress.isHidden = upload?.error != nil || upload?.state == .uploaded
            progress.state = upload?.state ?? .pending
          //  progress.progress = CGFloat(progressValue)

            errorBt.isHidden = upload?.error == nil
            done.isHidden = upload?.state != .uploaded

            thumbnail.image = upload?.thumbnail

            nameLb.text = upload?.filename

            if !(upload?.isReady ?? false) && upload?.state != .uploaded {
                sizeLb.text = NSLocalizedString("Encoding file…", comment: "")
            }
            else {
                let total = upload?.asset?.filesize ?? 0
                // The first 10% are for folder creation and metadata file upload, so correct for these.
                let done = Double(total) * (progressValue - 0.1) / 0.9

                if done > 0 {
                    // \u{2191} is up arrow
                    sizeLb.text = "\(Formatters.formatByteCount(total)) – \u{2191}\(Formatters.formatByteCount(Int64(done)))"
                }
                else {
                    sizeLb.text = Formatters.formatByteCount(total)
                }
            }
        }
    }

    weak var delegate: UploadCellDelegate?


    // MARK: Actions

    @IBAction
    func progressTapped() {
        if let upload = upload {
            delegate?.progressTapped(upload, progress)
        }
    }

    @IBAction
    func deleteTapped() {
        if let upload = upload {
            delegate?.delete(upload,from: self)
        }
    }
    @IBAction func showError() {
        if let upload = upload {
            delegate?.showError(upload)
        }
    }
}
