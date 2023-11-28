//
//  IaGuideSlideViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 28.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class IaGuideSlideViewController: BaseViewController {

    @IBOutlet weak var label: UILabel!

    @IBOutlet weak var imageView: UIImageView!

    var index: Int?

    var slide: Slide?

    override func viewDidLoad() {
        super.viewDidLoad()

        label.text = slide?.text

        if let image = slide?.image {
            imageView.image = UIImage(named: image)
        }
    }

    struct Slide {

        let text: String

        let image: String
    }
}
