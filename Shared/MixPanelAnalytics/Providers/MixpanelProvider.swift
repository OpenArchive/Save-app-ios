//
//  MixpanelProvider.swift
//  Save
//
//  Created by navoda on 2025-12-12.
//  Copyright © 2025 Open Archive. All rights reserved.
//


//
//  MixpanelProvider.swift
//  SaveAnalytics
//
//  Mixpanel analytics provider implementation
//

import Foundation
import Mixpanel

public class MixpanelProvider: AnalyticsProvider {
    private let token: String
    private var mixpanel: MixpanelInstance?

    public var providerName: String { "Mixpanel" }

    public init(token: String) {
        self.token = token
    }

    public func initialize() {
        mixpanel = Mixpanel.initialize(token: token, trackAutomaticEvents: true)
    }

    public func trackEvent(_ event: AnalyticsEvent) {
        guard let mixpanel = mixpanel else {
            return
        }

        // Sanitize properties to remove PII
        let sanitizedProperties = PIISanitizer.sanitize(properties: event.properties)

        // Convert to Properties type for Mixpanel
        let properties: Properties = sanitizedProperties as? Properties ?? [:]
        mixpanel.track(event: event.eventName, properties: properties)
    }

    public func setUserProperty(key: String, value: Any) {
        guard let mixpanel = mixpanel else { return }

        let sanitizedValue = PIISanitizer.sanitizeValue(value)

        // Convert to MixpanelType
        if let mixpanelValue = sanitizedValue as? MixpanelType {
            mixpanel.people.set(property: key, to: mixpanelValue)
        } else if let stringValue = sanitizedValue as? String {
            mixpanel.people.set(property: key, to: stringValue)
        } else if let numberValue = sanitizedValue as? NSNumber {
            mixpanel.people.set(property: key, to: numberValue)
        } else if let dateValue = sanitizedValue as? Date {
            mixpanel.people.set(property: key, to: dateValue)
        } else if let arrayValue = sanitizedValue as? [Any] {
            mixpanel.people.set(property: key, to: arrayValue)
        } else {
            // Fallback to string representation
            mixpanel.people.set(property: key, to: String(describing: sanitizedValue))
        }
    }

    public func reset() {
        mixpanel?.reset()
    }

    public func flush() {
        mixpanel?.flush()
    }
}
