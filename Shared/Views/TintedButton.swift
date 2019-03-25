//
//  TintedButton.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TintedButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    /**
     Automatically use the `normal` state image as template for `highlighted` and
     `selected` states. They will be colored with the current tint color.
    */
    private func setup() {
        setImage(image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .highlighted)
        setImage(image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .selected)
    }
}
