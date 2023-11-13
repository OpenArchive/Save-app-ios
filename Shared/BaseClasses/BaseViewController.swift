//
//  BaseViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 16.01.19.
//  Copyright © 2019 Guardian Project. All rights reserved.
//

import UIKit

/**
 Provides some helper methods which are always needed when it comes to keyboard
 handling.
 */
open class BaseViewController: UIViewController {
    
    @IBOutlet public var scrollView: UIScrollView?
    
    private var originalInsets: UIEdgeInsets?
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        let nc = NotificationCenter.default
        
        nc.addObserver(self,
                       selector: #selector(keyboardWillShow(notification:)),
                       name: UIResponder.keyboardWillShowNotification,
                       object: nil)
        
        nc.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)),
                       name: UIResponder.keyboardWillHideNotification,
                       object: nil)
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        let nc = NotificationCenter.default

        nc.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    /**
     Adds a `UITapGestureRecognizer` to the root `UIView` which hides the
     soft keyboard, if one is shown, so users can hide the keyboard this way.
    */
    public func hideKeyboardOnOutsideTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    /**
     Hides the soft keyboard, if one is shown.
    */
    @objc public func dismissKeyboard() {
        view.endEditing(true)
    }
    
    /**
     Callback for `UIResponder.keyboardWillShowNotification`.
     
     - parameter notification: The calling notification.
    */
    @objc open func keyboardWillShow(notification: Notification) {
        if let scrollView = scrollView,
           let kbSize = getKeyboardSize(notification)
        {
            if originalInsets == nil {
                originalInsets = scrollView.contentInset
            }
            
            var insets = originalInsets!
            insets.bottom = insets.bottom + kbSize.height
            
            scrollView.contentInset = insets
            scrollView.scrollIndicatorInsets = insets
            
            animateDuringKeyboardMovement(notification)
        }
    }
    
    /**
     Callback for `UIResponder.keyboardWillHideNotification`.
     
     - parameter notification: A `keyboardWillHideNotification`. Ignored.
     */
    @objc open func keyboardWillBeHidden(notification: Notification) {
        scrollView?.contentInset = originalInsets ?? .zero
        scrollView?.scrollIndicatorInsets = originalInsets ?? .zero
        
        animateDuringKeyboardMovement(notification)
    }
    
    /**
     - parameter notification: A `keyboardWillShowNotification`.
     - returns: the keyboard sizing from a given notification, if any contained.
     */
    public func getKeyboardSize(_ notification: Notification) -> CGRect? {
        guard let frameEnd = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return nil
        }

        let screen = notification.object as? UIScreen
        if let convertedFrameEnd = screen?.coordinateSpace.convert(frameEnd, to: view) {
            return view.bounds.intersection(convertedFrameEnd)
        }

        return frameEnd
    }
    
    /**
     - parameter notification: A `keyboardWillShowNotification` or `keyboardWillHideNotification`.
     - returns: the animation duration from a given notification, if any contained,
     or a safe default.
     */
    public func getKeyboardAnimationDuration(_ notification: Notification) -> TimeInterval {
        return (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? NSNumber)?.doubleValue  ?? 0.25
    }
    
    /**
     Animates changes in layout with the same speed as the keyboard shows/withdraws.
     
     Set any changes to your layout before calling this!
     
     - parameter notification: A `keyboardWillShowNotification` or `keyboardWillHideNotification`.
     */
    public func animateDuringKeyboardMovement(_ notification: Notification) {
        UIView.animate(withDuration: getKeyboardAnimationDuration(notification),
                       animations: { self.view.layoutIfNeeded() })
    }

    
    // MARK: Actions
    
    /**
     Dismisses ourselves, animated.
     Handles being in a `UINavigationController` gracefully.
     
     Can be a callback for simple "Cancel", "Done" etc. buttons.

     - parameter sender: The triggering UI element. Ignored. Just there so attachments from Storyboard work without issues.
     - parameter completion: Block to be executed after animation has ended.
     */
    @IBAction public func dismiss(_ sender: Any? = nil, _ completion: (() -> Void)? = nil) {
        if let nav = navigationController {
            nav.popViewController(animated: true)

            if let completion = completion {
                nav.transitionCoordinator?.animate(alongsideTransition: nil, completion: { _ in
                    completion()
                })
            }
        }
        else {
            dismiss(animated: true, completion: completion)
        }
    }
}
