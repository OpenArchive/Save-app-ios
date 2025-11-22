//
//  ImageViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UIImageViewAlignedSwift

class ImageViewController: UIViewController {

    @IBOutlet weak var defaultImage: UIImageView!
    @IBOutlet weak var defaultView: UIView!
    @IBOutlet weak var imageView: UIImageViewAligned!
    @IBOutlet weak var movieIndicator: MovieIndicator!

    var image: UIImage?
    var placeholderImage:UIImage?
    var isThumbnail:Bool?
    var index: Int?

    var isAv: Bool?

    var duration: TimeInterval?

    override func viewDidLoad() {
        super.viewDidLoad()
        if(isThumbnail ?? false){
            imageView.isHidden = false
            defaultView.isHidden = true
            imageView.image = image
            imageView.contentMode = .scaleAspectFill
            movieIndicator.isHidden = !(isAv ?? false)
            movieIndicator.set(duration: duration)
            movieIndicator.inset(9.5)
        }else{
            movieIndicator.isHidden = true
            imageView.isHidden = true
            defaultView.isHidden = false
            defaultImage.image = placeholderImage
        }
        
    }
}
