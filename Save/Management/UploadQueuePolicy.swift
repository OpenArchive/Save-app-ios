//
//  UploadQueuePolicy.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

enum UploadQueuePolicy {
    static let maxAutoRetries = 3
    static let largeFileThreshold = Conduit.chunkFileSizeThreshold
    /// IA often returns a brief/transient 503; a short wait then retry usually works.
    /// Keep this small — only extend if the post-wake retry is still 503.
    static let iaCooldownInitialMinutes = 1
    static let iaCooldownIncrementMinutes = 2
    /// Cap cooldown at this duration to prevent infinite growth if IA server stays down.
    static let iaCooldownMaxMinutes = 15
    /// Pause after an IA success before the next item (matches ~3–5s IA CLI pacing).
    static let iaSuccessPacingSeconds: TimeInterval = 4.0
    static let iaBusyMessage = NSLocalizedString("Internet Archive servers are busy.", comment: "")
    static let noNetworkMessage = NSLocalizedString("No network connection.", comment: "")
    static let wifiRequiredMessage = NSLocalizedString("Wi‑Fi connection required.", comment: "")
    static let duplicateHttpStatuses: Set<Int> = [409, 412]

    static func isConnectivityErrorMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        return message == noNetworkMessage || message == wifiRequiredMessage
    }
}
