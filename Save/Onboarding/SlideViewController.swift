//
//  SlideViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UIImageViewAlignedSwift

class SlideViewController: UIViewController {

    @IBOutlet weak var headingLb: UILabel!
    @IBOutlet weak var textLb: UILabel!
    @IBOutlet weak var illustrationImg: UIImageViewAligned!

    var index: Int?
    var heading: String?
    var text: String?
    var illustration: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()

        headingLb.text = heading
        textLb.text = text
        illustrationImg.image = illustration
        illustrationImg.alignment = .topLeft
    }
}
