//
//  ImageViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {

    class func initFromStoryboard() -> ImageViewController? {
        return UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "imageViewController") as? ImageViewController
    }

    @IBOutlet weak var imageView: UIImageView!

    var image: UIImage?

    var index: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = image
    }
}
