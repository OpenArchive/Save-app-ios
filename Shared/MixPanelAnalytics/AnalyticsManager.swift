//
//  AnalyticsManager.swift
//  SaveAnalytics
//
//  Unified analytics manager - main entry point for tracking events
//  Sends events to all configured providers (Mixpanel, etc.)
//

import Foundation

public class AnalyticsManager {

    // MARK: - Singleton

    public static let shared = AnalyticsManager()

    // MARK: - Properties

    // Serial queue for async, non-blocking event tracking
    private let trackingQueue = DispatchQueue(label: "com.openarchive.analytics", qos: .utility)

    private var providers: [AnalyticsProvider] = []
    private var isInitialized = false

    // MARK: - Initialization

    private init() {}

    /// Initialize analytics with providers
    /// - Parameter providers: Array of analytics providers to use
    public func initialize(providers: [AnalyticsProvider]) {
        guard !isInitialized else {
            #if DEBUG
            print("[AnalyticsManager] ⚠️ Already initialized")
            #endif
            return
        }

        self.providers = providers

        // Initialize all providers
        providers.forEach { $0.initialize() }

        isInitialized = true
        #if DEBUG
        print("[AnalyticsManager] ✅ Initialized with \(providers.count) provider(s)")
        #endif
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    /// Fully async and non-blocking - returns immediately
    /// - Parameter event: The event to track
    public func trackEvent(_ event: AnalyticsEvent) {
        guard isInitialized else {
            #if DEBUG
            print("[AnalyticsManager] ⚠️ Not initialized - skipping event: \(event.eventName)")
            #endif
            return
        }

        // Offload to background queue immediately - no blocking
        trackingQueue.async { [weak self] in
            guard let self = self else { return }

            // Send to all providers on background thread
            // PIISanitizer (if used by providers) runs here, not on main thread
            self.providers.forEach { provider in
                provider.trackEvent(event)
            }
        }
    }

    // MARK: - Convenience Methods

    /// Track a feature toggle
    public func trackFeatureToggled(featureName: String, enabled: Bool) {
        trackEvent(.featureToggled(featureName: featureName, enabled: enabled))
    }

    /// Track a screen view
    public func trackScreenViewed(screenName: String, timeSpent: TimeInterval? = nil, previousScreen: String? = nil) {
        trackEvent(.screenViewed(screenName: screenName, timeSpent: timeSpent, previousScreen: previousScreen))
    }

    /// Track an error
    public func trackError(errorCategory: String, screenName: String? = nil, backendType: String? = nil) {
        trackEvent(.errorOccurred(errorCategory: errorCategory, screenName: screenName, backendType: backendType))
    }

    // MARK: - Session Management

    /// Start a new analytics session
    public func startSession() {
        SessionManager.shared.startSession()

        let isFirstSession = SessionManager.shared.isFirstSessionEver()
        let sessionNumber = SessionManager.shared.getSessionNumber()

        trackEvent(.sessionStarted(isFirstSession: isFirstSession, sessionNumber: sessionNumber))
    }

    /// End the current analytics session
    public func endSession() {
        let duration = SessionManager.shared.endSession()
        let lastScreen = SessionManager.shared.getLastScreen()
        let uploadsCompleted = SessionManager.shared.sessionUploadsCompleted
        let uploadsFailed = SessionManager.shared.sessionUploadsFailed

        trackEvent(.sessionEnded(
            lastScreen: lastScreen,
            duration: duration,
            uploadsCompleted: uploadsCompleted,
            uploadsFailed: uploadsFailed
        ))
    }

    // MARK: - User Properties

    /// Set a user property
    /// Async and non-blocking
    public func setUserProperty(key: String, value: Any) {
        guard isInitialized else { return }

        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.providers.forEach { provider in
                provider.setUserProperty(key: key, value: value)
            }
        }
    }

    // MARK: - Reset

    /// Reset all analytics data (for logout/privacy)
    /// Async and non-blocking
    public func reset() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.providers.forEach { $0.reset() }
            SessionManager.shared.reset()
            #if DEBUG
            print("[AnalyticsManager] 🔄 Reset complete")
            #endif
        }
    }

    /// Flush pending events
    /// Async and non-blocking
    public func flush() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.providers.forEach { $0.flush() }
        }
    }
}

// MARK: - Global Convenience Functions

/// Global function for easy event tracking
public func trackEvent(_ event: AnalyticsEvent) {
    AnalyticsManager.shared.trackEvent(event)
}

/// Global function for tracking feature toggles
public func trackFeatureToggled(featureName: String, enabled: Bool) {
    AnalyticsManager.shared.trackFeatureToggled(featureName: featureName, enabled: enabled)
}

/// Global function for tracking screen views
public func trackScreenViewed(screenName: String, timeSpent: TimeInterval? = nil, previousScreen: String? = nil) {
    AnalyticsManager.shared.trackScreenViewed(screenName: screenName, timeSpent: timeSpent, previousScreen: previousScreen)
}

/// Global function for tracking errors
public func trackError(errorCategory: String, screenName: String? = nil, backendType: String? = nil) {
    AnalyticsManager.shared.trackError(errorCategory: errorCategory, screenName: screenName, backendType: backendType)
}
