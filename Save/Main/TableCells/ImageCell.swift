//
//  ImageCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ImageCell: UICollectionViewCell {
    
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var fileImage: UIImageView!
    @IBOutlet weak var defaultFileType: UIView!
    
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
        fileName.text = asset?.filename
        self.asset = asset
        self.upload = upload
        
       
        if asset?.hasThumbnail() == true {
            imgView.isHidden = false
            defaultFileType.isHidden = true
            imgView.isHidden = false
            
            // Get thumbnail asynchronously
            asset?.getThumbnailAsync { [weak self] image in
                guard let self = self else { return }
                
                self.imgView.image = image
                
                applyBlurIfNeeded(to: imgView, asset: asset, upload: upload)
                if asset?.isAv ?? false {
                    movieIndicator.isHidden = false
                    movieIndicator.set(duration: asset?.duration)
                }
                else {
                    movieIndicator.isHidden = true
                }
            }
        } else {
            
            imgView.isHidden = true
            defaultFileType.isHidden = false
            movieIndicator.isHidden = true
            fileImage.image = UIImage(named: asset?.getFileType().placeholder ?? "unknown")
            
            applyBlurIfNeeded(to: defaultFileType, asset: asset, upload: upload)
            
        }
        
        progress.isHidden = upload == nil || asset?.isUploaded ?? true || upload?.state == .uploaded
        progress.state = upload?.state ?? .pending
        print("upload progress\(String(describing: upload?.progress))")
        progress.progress = upload?.progress ?? 0
        
        errorIcon.isHidden = true
        
        if upload?.error != nil {
            errorIcon.isHidden = false
            progress.isHidden = true
            
            return
        }
        
    }
    
    private func applyBlurIfNeeded(to superview: UIView, asset: Asset?, upload: Upload?) {
       
        guard highlightNonUploaded,
              !(asset?.isUploaded ?? false),
              !UIAccessibility.isReduceTransparencyEnabled else {
          
            blurViewDark?.removeFromSuperview()
            blurViewLight?.removeFromSuperview()
            return
        }
      
        let shouldUseDarkBlur = (upload?.state == .uploading || upload?.state == .pending) && upload?.error == nil
        
        if shouldUseDarkBlur {
           
            blurViewLight?.removeFromSuperview()
       
            if blurViewDark == nil {
                blurViewDark = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
                blurViewDark?.alpha = 0.65
                blurViewDark?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
            
            blurViewDark?.frame = superview.bounds
            superview.addSubview(blurViewDark!)
        } else {
          
            blurViewDark?.removeFromSuperview()
            
            if blurViewLight == nil {
                blurViewLight = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
                blurViewLight?.alpha = 0.35
                blurViewLight?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
            
            blurViewLight?.frame = superview.bounds
            superview.addSubview(blurViewLight!)
        }
    }
}
