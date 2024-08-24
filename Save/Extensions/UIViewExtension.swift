//
//  Created by Richard Puckett on 5/25/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension UIView {
    
    public enum ElementAttribute: Int {
        case border    = 0
        case tint      = 1
    }
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        
        return nil
    }
    
    func addGradient(colors: [CGColor] = [UIColor.black.cgColor, UIColor.white.cgColor]) {
        let gradientLayerName = "gradientLayer"
        
        if let oldlayer = self.layer.sublayers?.filter({$0.name == gradientLayerName}).first {
            oldlayer.removeFromSuperlayer()
        }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0.55, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1 )
        gradientLayer.locations = [0, 0.85]
        gradientLayer.frame = self.bounds
        gradientLayer.name = gradientLayerName
        
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func addShadows(tinted color: UIColor = .black.withAlphaComponent(0.50)) {
        let topShadow = GradientView()
        topShadow.startColor = color
        topShadow.endColor = color.withAlphaComponent(0)
        
        let bottomShadow = GradientView()
        bottomShadow.startColor = color.withAlphaComponent(0)
        bottomShadow.endColor = color
        
        addSubview(topShadow)
        addSubview(bottomShadow)
        
        topShadow.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(10)
        }
        
        bottomShadow.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(10)
        }
    }
    
    public func addSubViews(_ views: [UIView]) {
        views.forEach({
            self.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        })
    }
    
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
    func flash(color: UIColor, delay: CGFloat = 0.0, for attribute: ElementAttribute, completion: (() -> Void)? = nil) {
        let originalBorderWidth = layer.borderWidth
        let originalBorderColor = layer.borderColor
        let originalTintColor = tintColor
        
        UIView.animate(withDuration: 0.10, delay: delay, options: [.autoreverse, .repeat], animations: {
            UIView.modifyAnimations(withRepeatCount: 3, autoreverses: true) {
                if attribute == .border {
                    self.layer.borderWidth = 2
                    self.layer.borderColor = color.cgColor
                } else {
                    self.tintColor = color
                }
            }
        }, completion: { _ in
            if attribute == .border {
                self.layer.borderWidth = originalBorderWidth
                self.layer.borderColor = originalBorderColor
            } else {
                self.tintColor = originalTintColor
            }
            
            completion?()
        })
    }
    
    func hide(duration: CGFloat = 0.25, alpha: Double = 0, completion: (() -> Void)? = nil) {
        if self.alpha == alpha { return }
        
        if duration == 0 {
            self.alpha = alpha
            return
        }
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                self.alpha = alpha
            }, completion: { finished in
                completion?()
            })
        }
    }
    
    func isVisible() -> Bool {
        return alpha != 0
    }
    
    func toggleVisibility(duration: CGFloat = AppStyle.animationDuration) {
        if alpha == 0 {
            show(duration: duration)
        } else {
            hide(duration: duration)
        }
    }
    
    func pop() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        
        animation.values = [1.0, 1.1, 1.0]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = 0.15
        animation.repeatCount = 0
        
        layer.add(animation, forKey: nil)
    }
    
    func sizeForWidth(width: CGFloat) -> CGSize {
        let targetSize = CGSize(
            width: width,
            height: 0)
        
        return systemLayoutSizeFitting(targetSize,
                                       withHorizontalFittingPriority: .required,
                                       verticalFittingPriority: .defaultLow)
    }
    
    func screenshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        
        return renderer.image { rendererContext in
            self.layer.render(in: rendererContext.cgContext)
        }
    }
    
    func setAnchorPoint(_ point: CGPoint) {
        var newPoint = CGPoint(x: bounds.size.width * point.x, y: bounds.size.height * point.y)
        var oldPoint = CGPoint(x: bounds.size.width * layer.anchorPoint.x, y: bounds.size.height * layer.anchorPoint.y);
        
        newPoint = newPoint.applying(transform)
        oldPoint = oldPoint.applying(transform)
        
        var position = layer.position
        
        position.x -= oldPoint.x
        position.x += newPoint.x
        
        position.y -= oldPoint.y
        position.y += newPoint.y
        
        layer.position = position
        layer.anchorPoint = point
    }
    
    func show(duration: Double = 0.25, alpha: Double = 1, completion: (() -> Void)? = nil) {
        if self.alpha > 0.02 { return }
        
        if duration == 0 {
            self.alpha = alpha
            return
        }
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                self.alpha = alpha
            }, completion: { finished in
                completion?()
            })
        }
    }
    
    var dropShadow: Bool {
        get {
            return self.layer.shadowRadius > 0
        }
        set {
            if newValue {
                self.layer.zPosition = 1000
                self.layer.shadowColor = UIColor.black.cgColor
                self.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.layer.shadowRadius = 2
                self.layer.shadowOpacity = 0.5
            } else {
                self.layer.zPosition = 1000
                self.layer.shadowColor = UIColor.clear.cgColor
                self.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.layer.shadowRadius = 0
                self.layer.shadowOpacity = 0
            }
        }
    }
    
    var heightConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
    
    var widthConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .width && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
}
