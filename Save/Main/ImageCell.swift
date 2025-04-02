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

    private var blurViewDark: UIVisualEffectView?
    private var blurViewLight: UIVisualEffectView?

    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var progress: ProgressButton!
    @IBOutlet weak var errorIcon: UIImageView!
    @IBOutlet weak var movieIndicator: MovieIndicator!

    private lazy var selectedView = SelectedView()

    var highlightNonUploaded = true

    private(set) weak var asset: Asset?
    private(set) weak var upload: Upload?

    override var isSelected: Bool {
        didSet {
            if isSelected {
                selectedView.addToSuperview(self)
            }
            else {
                selectedView.removeFromSuperview()
            }
        }
    }

    func set(_ asset: Asset?, _ upload: Upload?) {
        self.asset = asset
        self.upload = upload

        imgView.image = asset?.getThumbnail()

        if highlightNonUploaded && !(asset?.isUploaded ?? false) && !UIAccessibility.isReduceTransparencyEnabled {
            if upload?.state == .uploading || upload?.state == .pending && upload?.error == nil {
                if blurViewDark == nil {
                    blurViewDark = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
                    blurViewDark?.alpha = 0.65
                    blurViewDark?.frame = imgView.bounds
                    blurViewDark?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                }

                imgView.addSubview(blurViewDark!)
            }
            else {
                if blurViewLight == nil {
                    blurViewLight = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
                    blurViewLight?.alpha = 0.35
                    blurViewLight?.frame = imgView.bounds
                    blurViewLight?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                }

                imgView.addSubview(blurViewLight!)
            }
        }
        else {
            blurViewDark?.removeFromSuperview()
            blurViewLight?.removeFromSuperview()
        }

        if asset?.isAv ?? false {
            movieIndicator.isHidden = false
            movieIndicator.set(duration: asset?.duration)
        }
        else {
            movieIndicator.isHidden = true
        }

        if upload?.error != nil {
            errorIcon.isHidden = false
            progress.isHidden = true

            return
        }

        errorIcon.isHidden = true

        progress.isHidden = upload == nil || asset?.isUploaded ?? true || upload?.state == .uploaded
        progress.state = upload?.state ?? .pending
       // progress.progress = upload?.progress ?? 0
    }
}
