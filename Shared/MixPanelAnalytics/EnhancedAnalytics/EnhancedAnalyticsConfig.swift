//
//  EnhancedAnalyticsConfig.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

/// Build-time flag for enhanced analytics (tester dialog, Session Replay, testing banner).
/// Toggle in Shared/Config.xcconfig: ENHANCED_ANALYTICS_ENABLED = YES or NO
enum EnhancedAnalyticsConfig {

    static var isEnabled: Bool {
        guard let value = Bundle.main.infoDictionary?["ENHANCED_ANALYTICS_ENABLED"] as? String else {
            return false
        }
        return value.uppercased() == "YES"
    }
}
