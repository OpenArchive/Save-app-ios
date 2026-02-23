//
//  UIViewController+Analytics.swift
//  Save
//
//  UIViewController extension for automatic screen tracking
//

import UIKit

extension UIViewController {

    
    /// - Parameter screenName: Optional custom screen name. If nil, uses class name.
    func trackScreenViewSafely(_ screenName: String? = nil) {
        // Extract screen name from class if not provided
        let screen = screenName ?? String(describing: type(of: self))
            .replacingOccurrences(of: "ViewController", with: "")
            .replacingOccurrences(of: "Controller", with: "")

        MixPanelSessionManager.shared.setCurrentScreen(screen)
        let previousScreen = MixPanelSessionManager.shared.getPreviousScreen()
        trackScreenViewed(screenName: screen, previousScreen: previousScreen)
    }
}
