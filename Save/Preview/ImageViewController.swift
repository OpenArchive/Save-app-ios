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

    @IBOutlet weak var imageView: UIImageViewAligned!
    @IBOutlet weak var movieIndicator: MovieIndicator!

    var image: UIImage?

    var index: Int?

    var isAv: Bool?

    var duration: TimeInterval?

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        movieIndicator.isHidden = !(isAv ?? false)
        movieIndicator.set(duration: duration)
        movieIndicator.inset(9.5)
    }
}
