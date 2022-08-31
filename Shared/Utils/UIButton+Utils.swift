//
//  UIButton+Utils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.02.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit

extension UIButton {

    func setTitle(_ title: String?) {
        setTitle(title, for: .normal)
        setTitle(title, for: .highlighted)
        setTitle(title, for: .disabled)
        setTitle(title, for: .focused)
        setTitle(title, for: .selected)
    }

    func setImage(_ image: UIImage?) {
        setImage(image, for: .normal)
        setImage(image, for: .highlighted)
        setImage(image, for: .disabled)
        setImage(image, for: .focused)
        setImage(image, for: .selected)
    }
}
