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

    var image: UIImage?

    var index: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = image
        imageView.alignment = .top
    }
}
