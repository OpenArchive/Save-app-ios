//
//  SessionReplayManager.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import Mixpanel
import MixpanelSessionReplay

final class SessionReplayManager {

    static let shared = SessionReplayManager()
    private(set) var isInitialized = false

    func initialize(distinctId: String) {
        guard EnhancedAnalyticsConfig.isEnabled else { return }
        guard !isInitialized else { return }

        let mixpanel = Mixpanel.mainInstance()
        var config = MPSessionReplayConfig(
            wifiOnly: false,
            autoMaskedViews: [],
            recordingSessionsPercent: 100.0,
            enableLogging: false
        )
        config.enableSessionReplayOniOS26AndLater = true

        MPSessionReplay.initialize(
            token: mixpanel.apiToken,
            distinctId: distinctId,
            config: config
        )

        isInitialized = true
    }

    func startRecording() {
        guard isInitialized else { return }
        MPSessionReplay.getInstance()?.startRecording()
    }

    func stopRecording() {
        guard isInitialized else { return }
        MPSessionReplay.getInstance()?.stopRecording()
    }

    func flush() {
        guard isInitialized else { return }
        MPSessionReplay.getInstance()?.flush()
    }

    func reset() {
        isInitialized = false
    }
}
