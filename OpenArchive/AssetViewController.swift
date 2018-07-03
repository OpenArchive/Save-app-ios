//
//  AssetViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class AssetViewController: UIViewController {

    @IBOutlet var image: UIImageView!
    @IBOutlet var dateLb: UILabel!
    @IBOutlet var descriptionTf: UITextField!
    @IBOutlet var authorTf: UITextField!
    @IBOutlet var locationTf: UITextField!
    @IBOutlet var tagsTf: UITextField!
    @IBOutlet var licenseTf: UITextField!
    
    var imageObject: Image?

    override func viewDidLoad() {
        super.viewDidLoad()

        image.image = imageObject?.image

        if let created = imageObject?.created {
            dateLb.text = Formatters.date.string(from: created)
        }

        descriptionTf.text = imageObject?.desc
        authorTf.text = imageObject?.author
        locationTf.text = imageObject?.location
        tagsTf.text = imageObject?.tags?.joined(separator: ", ")
        licenseTf.text = imageObject?.license
    }

}
