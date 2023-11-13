//
//  GradientView.swift
//  Save
//
//  Created by Benjamin Erhart on 13.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class GradientView: UIView {

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }


    var gradient: CAGradientLayer {
        layer as! CAGradientLayer
    }


    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }


    private func setup() {
        gradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        gradient.locations = [0, 1]
    }
}
