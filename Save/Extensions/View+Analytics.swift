//
//  View+Analytics.swift
//  Save
//
//  SwiftUI View extension for screen tracking analytics
//

import SwiftUI

extension View {

    func trackScreen(_ screenName: String) -> some View {
        onAppear {
            MixPanelSessionManager.shared.setCurrentScreen(screenName)
            let previousScreen = MixPanelSessionManager.shared.getPreviousScreen()
            trackScreenViewed(screenName: screenName, previousScreen: previousScreen)
        }
    }
}
