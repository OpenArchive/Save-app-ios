//
//  TintedButton.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

@IBDesignable
class TintedButton: UIButton {

    @IBInspectable
    var selectedColor: UIColor?


    private var unselectedColor: UIColor?


    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }


    open override var isSelected: Bool {
        didSet {
            guard let selectedColor = selectedColor else {
                return
            }

            if isSelected {
                if unselectedColor == nil {
                    unselectedColor = tintColor
                }

                tintColor = selectedColor
            }
            else {
                tintColor = unselectedColor ?? tintColor
                unselectedColor = nil
            }
        }
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
