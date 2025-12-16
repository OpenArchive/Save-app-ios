//
//  AnalyticsProvider.swift
//  Save
//
//  Created by navoda on 2025-12-12.
//  Copyright © 2025 Open Archive. All rights reserved.
//


//
//  AnalyticsProvider.swift
//  SaveAnalytics
//
//  Protocol for analytics providers (Mixpanel, Firebase, CleanInsights)
//

import Foundation

/// Protocol that all analytics providers must implement
public protocol AnalyticsProvider {
    /// Initialize the analytics provider
    func initialize()

    /// Track an analytics event
    /// - Parameters:
    ///   - event: The event to track
    func trackEvent(_ event: AnalyticsEvent)

    /// Set a user property (for user-scoped analytics)
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    func setUserProperty(key: String, value: Any)

    /// Reset user data (for privacy/logout)
    func reset()

    /// Flush pending events (optional, for immediate sending)
    func flush()

    /// Provider name for debugging
    var providerName: String { get }
}

/// Default implementations
public extension AnalyticsProvider {
    func setUserProperty(key: String, value: Any) {
        // Optional - not all providers need this
    }

    func flush() {
        // Optional - not all providers need manual flushing
    }
}
