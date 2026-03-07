//
//  EnhancedMixpanelProvider.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import Mixpanel
import UIKit

/// Mixpanel provider for staging/dev builds: no PII sanitization, named user identification, Session Replay.
public class EnhancedMixpanelProvider: AnalyticsProvider, UserIdentifiableProvider {
    private static var environmentName: String {
        #if DEBUG
        return "dev"
        #else
        return "staging"
        #endif
    }

    private let token: String
    private var mixpanel: MixpanelInstance?

    public var providerName: String { "EnhancedMixpanel" }

    public init(token: String) {
        self.token = token
    }

    public func initialize() {
        mixpanel = Mixpanel.initialize(token: token, trackAutomaticEvents: true)
    }

    public func trackEvent(_ event: AnalyticsEvent) {
        guard let mixpanel = mixpanel else { return }

        // No PII sanitization for staging/dev
        let properties: Properties = event.properties as? Properties ?? [:]
        mixpanel.track(event: event.eventName, properties: properties)
    }

    public func setUserProperty(key: String, value: Any) {
        guard let mixpanel = mixpanel else { return }

        if let mixpanelValue = value as? MixpanelType {
            mixpanel.people.set(property: key, to: mixpanelValue)
        } else if let stringValue = value as? String {
            mixpanel.people.set(property: key, to: stringValue)
        } else if let numberValue = value as? NSNumber {
            mixpanel.people.set(property: key, to: numberValue)
        } else if let dateValue = value as? Date {
            mixpanel.people.set(property: key, to: dateValue)
        } else if let arrayValue = value as? [Any] {
            mixpanel.people.set(property: key, to: arrayValue)
        } else {
            mixpanel.people.set(property: key, to: String(describing: value))
        }
    }

    public func identifyUser(email: String, name: String? = nil) {
        guard let mixpanel = mixpanel else { return }
        guard EnhancedAnalyticsConfig.isEnabled else { return }

        mixpanel.identify(distinctId: email)
        mixpanel.people.set(properties: [
            "$email": email,
            "$name": name ?? email,
            "environment": Self.environmentName,
            "device": UIDevice.current.model,
            "device_os": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "first_seen": ISO8601DateFormatter().string(from: Date())
        ])

        SessionReplayManager.shared.initialize(distinctId: email)
    }

    public func resetUser() {
        mixpanel?.reset()
        SessionReplayManager.shared.reset()
    }

    public func reset() {
        resetUser()
    }

    public func flush() {
        mixpanel?.flush()
        SessionReplayManager.shared.flush()
    }
}
