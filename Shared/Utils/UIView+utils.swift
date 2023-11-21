//
//  UIView+animateHideShow.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 26.02.19.
//  Copyright © 2019 Guardian Project. All rights reserved.
//

import UIKit

/**
 This extension provides some helper methods to hide/show `UIView`s.
 
 They are not only working on the `#isHidden` property, but also on height
 constraints, which will be modified, if existing or added anew, if not.
 
 Please note: This currently works properly only with horizontally designed
 layouts. For best effect, make all views dependent on their top neighbor's
 bottom and give height constraints to all necessary elements.
 
 You will be annoyed by a lot of constraint-break warnings, if the child elements
 also contain height constraints. They should be unproblematic. However, it is
 unclear how to avoid them without going through the hassle and remove all of
 them beforehand and restore them afterwards. (Which asks the question of the
 data structure to use for an adventure like that...)
 */
@IBDesignable
extension UIView {
    
    /**
     Hides
     
     - parameter animated: If the change (if any) shall be animated or not.
    */
    func hide(animated: Bool = false, _ completion: ((_ finished: Bool) -> Void)? = nil) {

        if animated {
            animateHideShow(hide: true, completion)
        }
        else {
            isHidden = true
            completion?(true)
        }
    }
    
    /**
     Sets `isHidden` to `false`, and if `#hide` was called before, also sets
     a height constraint to the original (stored) height.

     TODO: The name is a quick hack, as it collides with MBProgressHUD.
     
     - parameter animated: If the change (if any) shall be animated or not.
    */
    func show2(animated: Bool = false, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        if animated {
            animateHideShow(hide: false, completion)
        }
        else {
            isHidden = false
            completion?(true)
        }
    }
    
    /**
     Sets the view hidden or shown, depending on the given toggle value.
     
     - parameter toggle: If true, view will be shown, if false view will be hidden.
     - parameter animated: If the change (if any) shall be animated or not.
    */
    func toggle(_ toggle: Bool, animated: Bool = false, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        if toggle {
            show2(animated: animated, completion)
        }
        else {
            hide(animated: animated, completion)
        }
    }
    
    
    // MARK: Private Methods
    
    /**
     Animate this view with a cross-dissolve transition to hidden/unhidden state,
     depending on the `hide` parameter, but only, if it's actually a change.
     
     - parameter hide: Set true to hide, false to unhide.
     */
    private func animateHideShow(hide: Bool, _ completion: ((_ finished: Bool) -> Void)?) {
        guard isHidden != hide else {
            return
        }

        if isHidden {
            alpha = 0
            isHidden = false

            UIView.animate(
                withDuration: 0.25,
                animations: { self.alpha = 1 },
                completion: completion)
        }
        else {
            UIView.animate(withDuration: 0.25) {
                self.alpha = 0
            } completion: { finished in
                self.isHidden = true
                self.alpha = 1

                completion?(finished)
            }
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor? {
        get {
            guard let color = layer.borderColor else {
                return nil
            }

            return UIColor(cgColor: color)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }

    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }
}
