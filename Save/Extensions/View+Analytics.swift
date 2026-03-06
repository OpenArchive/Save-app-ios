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
            SessionManager.shared.setCurrentScreen(screenName)
            let previousScreen = SessionManager.shared.getPreviousScreen()
            trackScreenViewed(screenName: screenName, previousScreen: previousScreen)
        }
    }
}
