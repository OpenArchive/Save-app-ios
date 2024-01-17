//
//  ProgressButton.swift
//  Save
//
//  Created by Benjamin Erhart on 14.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

@IBDesignable
class ProgressButton: UIView {

    @IBInspectable
    var lineWidth: CGFloat {
        get {
            circleLayer.lineWidth
        }
        set {
            circleLayer.lineWidth = newValue
        }
    }

    var state: Upload.State = .paused {
        didSet {
            manageAnimation()

            let cl = circleLayer
            cl.start = 0

            switch state {
            case .paused, .uploaded:
                cl.end = 1

            case .pending:
                cl.end = 0

            case .uploading:
                cl.end = progress
            }

            setNeedsDisplay()
        }
    }

    var progress: CGFloat = 0 {
        didSet {
            if progress < 0 {
                progress = 0
            }
            else if progress > 1 {
                progress = 1
            }

            if state == .uploading {
                circleLayer.end = progress
            }

            setNeedsDisplay()
        }
    }

    private var circleLayer: CircleLayer {
        layer as! CircleLayer
    }

    override class var layerClass: AnyClass {
        return CircleLayer.self
    }


    override func draw(_ rect: CGRect) {
        let size = rect.size
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width / 2, size.height / 2) - CGFloat(lineWidth) / 2

        circleLayer.borderColor = tintColor.cgColor

        switch state {
        case .paused:
            draw(image: .icUp, center: center, radius: radius)

        case .pending, .uploaded:
            break

        case .uploading:
            draw(text: Formatters.format(Int64(progress * 100)), center: center,
                 boundingSize: size, fontSize: radius * 0.9)
        }
    }


    // MARK: Public Methods

    func addTarget(_ target: Any?, action: Selector?) {
        let gr = UITapGestureRecognizer(target: target, action: action)

        addGestureRecognizer(gr)
        isUserInteractionEnabled = true
    }

    func removeTargets() {
        isUserInteractionEnabled = false

        for gr in gestureRecognizers ?? [] {
            removeGestureRecognizer(gr)
        }
    }


    // MARK: Private Methods

    private func manageAnimation() {
        if !isHidden && state == .pending {
            circleLayer.animate()
        }
        else {
            circleLayer.stopAnimation()
        }
    }

    private func draw(text: String, center: CGPoint, boundingSize: CGSize, fontSize: CGFloat) {
        var attributes = [NSAttributedString.Key: Any]()

        attributes[.font] = UIFont.montserrat(forTextStyle: .caption1).withSize(fontSize)

        if let color = tintColor {
            attributes[.foregroundColor] = color
        }

        let text = NSAttributedString(string: text, attributes: attributes)

        let textSize = text.boundingRect(
            with: boundingSize, 
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil)

        text.draw(at: .init(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))
    }

    private func draw(image: UIImage, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius / 2, y: center.y - radius / 2, width: radius, height: radius)

        image
            .withTintColor(tintColor, renderingMode: .alwaysTemplate)
            .draw(in: rect)
    }
}

fileprivate class CircleLayer: CALayer {

    private static let animationKey = "animateCircle"

    private static let animation: CABasicAnimation = {
        let animation = CABasicAnimation()
        animation.duration = 1
        animation.fromValue = 0
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = true
        animation.fillMode = .both

        return animation
    }()


    @objc
    var start: CGFloat = 0

    @objc
    var end: CGFloat = 0

    @objc
    var lineWidth: CGFloat = 1


    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let layer = layer as? CircleLayer {
            start = layer.start
            end = layer.end
            lineWidth = layer.lineWidth
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        start = CGFloat(coder.decodeFloat(forKey: "start"))
        end = CGFloat(coder.decodeFloat(forKey: "end"))
        lineWidth = CGFloat(coder.decodeFloat(forKey: "lineWidth"))
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)

        coder.encode(start, forKey: "start")
        coder.encode(end, forKey: "end")
        coder.encode(lineWidth, forKey: "lineWidth")
    }


    override class func needsDisplay(forKey key: String) -> Bool {
        switch key {
        case #keyPath(start), #keyPath(end), #keyPath(lineWidth):
            return true

        default:
            return super.needsDisplay(forKey: key)
        }
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)

        UIGraphicsPushContext(ctx)

        let color: UIColor

        if let borderColor = borderColor {
            color = UIColor(cgColor: borderColor)
        }
        else {
            color = .label
        }

        color.setStroke()

        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: min(bounds.size.width / 2, bounds.size.height / 2) - lineWidth / 2,
            startAngle: .pi * (-0.5 + 2 * start),
            endAngle: .pi * (-0.5 + 2 * end),
            clockwise: true)
        path.lineWidth = lineWidth

        path.stroke()

        UIGraphicsPopContext()
    }

    func animate() {
        guard !(animationKeys()?.contains(Self.animationKey) ?? false) else {
            return
        }

        let animIn = Self.animation.copy() as! CABasicAnimation
        animIn.keyPath = #keyPath(end)

        let animOut = Self.animation.copy() as! CABasicAnimation
        animOut.keyPath = #keyPath(start)
        animOut.beginTime = 1

        let animation = CAAnimationGroup()
        animation.animations = [animIn, animOut]
        animation.duration = 2
        animation.repeatCount = .infinity

        self.add(animation, forKey: Self.animationKey)
    }

    func stopAnimation() {
        removeAnimation(forKey: Self.animationKey)
    }
}
