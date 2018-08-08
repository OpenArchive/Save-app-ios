//
//  ImageCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class ImageCell: UITableViewCell {

    @IBOutlet var imgView: UIImageView!
    @IBOutlet var typeLb: UILabel!
    @IBOutlet var dateLb: UILabel!

    var asset: Asset? {
        didSet {
            self.imgView.image = asset?.getThumbnail()

            typeLb.text = asset?.mimeType

            if let created = asset?.created {
                dateLb.text = Formatters.date.string(from: created)
            }
            else {
                dateLb.text = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
