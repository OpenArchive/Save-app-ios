//
//  KeyboardHelper.swift
//  Save
//
//  Created by navoda on 2024-11-16.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit


class KeyboardHandling {

    weak var scrollView: UIScrollView!
    private var originalInsets: UIEdgeInsets?
    weak var viewController: UIViewController?
    init(scrollView: UIScrollView?,viewController: UIViewController?) {
        self.scrollView = scrollView
        registerKeyboardNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func registerKeyboardNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        // Convert keyboard frame to scrollView's coordinate space
        let keyboardFrameInWindow = keyboardSize
        let scrollViewFrameInWindow = scrollView.convert(scrollView.bounds, to: nil)
        
        // Calculate the intersection of the keyboard and scrollView
        let intersection = scrollViewFrameInWindow.intersection(keyboardFrameInWindow)
        
        // If there's no intersection, we don't need any padding
        if intersection.isNull {
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
            return
        }
        
        // Only add the height of the overlapping area as bottom inset
        let contentInsets = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: intersection.height,
            right: 0.0
        )
        
        // Adjust scroll view content insets
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // If there's an active text field, scroll to make it visible
        if let activeField = viewController?.view.findFirstResponder() as? UITextField {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            // Add some extra padding to ensure the text field isn't right at the keyboard
            let visibleRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y,
                width: rect.width,
                height: rect.height + 20 // Extra padding
            )
            scrollView.scrollRectToVisible(visibleRect, animated: true)
        }
    }

    @objc private func keyboardWillBeHidden(notification: Notification) {
        scrollView?.contentInset = originalInsets ?? .zero
        scrollView?.scrollIndicatorInsets = originalInsets ?? .zero
        animateDuringKeyboardMovement(notification)
    }

    private func getKeyboardSize(_ notification: Notification) -> CGRect? {
        guard let frameEnd = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return nil }
        return frameEnd
    }

    private func animateDuringKeyboardMovement(_ notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView?.superview?.layoutIfNeeded()
        }
    }
}
