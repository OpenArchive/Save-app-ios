//
//  ImageCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class ImageCell: UITableViewCell {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        return formatter
    }()

    @IBOutlet var imgView: UIImageView!
    @IBOutlet var dateLb: UILabel!

    var imageObject: Image? {
        didSet {
            imgView.image = imageObject?.image

            if let created = imageObject?.created {
                dateLb.text = ImageCell.dateFormatter.string(from: created)
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
