//
//  RoundedImageView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class RoundedImageView: UIImageView {

    override func layoutSubviews() {
        layer.cornerRadius = frame.width / 2
        layer.borderWidth = 3

        if #available(iOS 13.0, *) {
            layer.borderColor = UIColor.systemBackground.cgColor
        }
        else {
            layer.borderColor = UIColor.white.cgColor
        }

        super.layoutSubviews()
    }
}
