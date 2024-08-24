//
//  Created by Richard Puckett on 5/25/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class GradientView: UIView {
    var startColor: UIColor = .black
    var endColor: UIColor = .black
    
    override func draw(_ rect: CGRect) {
        let gradientLayerName = "gradientLayer"
        
        if let oldlayer = self.layer.sublayers?.filter({$0.name == gradientLayerName}).first {
            oldlayer.removeFromSuperlayer()
        }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [ startColor.cgColor, endColor.cgColor ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.locations = [0, 1]
        gradientLayer.frame = self.bounds
        gradientLayer.name = gradientLayerName
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
}
