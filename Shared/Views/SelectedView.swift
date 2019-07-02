//
//  SelectedView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 02.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class SelectedView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    func addToSuperview(_ superview: UIView) {
        superview.addSubview(self)

        let bounds = superview.bounds

        frame = CGRect(x: bounds.origin.x - 5,
                       y: bounds.origin.y - 5,
                       width: bounds.size.width + 10,
                       height: bounds.size.height + 10)

    }

    private func setup() {
        layer.borderColor = UIColor.accent.cgColor
        layer.borderWidth = 10
        layer.cornerRadius = 15
    }
}
