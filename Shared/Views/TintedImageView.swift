//
//  TintedImageView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TintedImageView: UIImageView {

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    /**
     Uses the current image as template, so it will be colored with the current
     tint color.
     */
    private func setup() {
        image = image?.withRenderingMode(.alwaysTemplate)
    }
}
