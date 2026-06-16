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
    static let iaCooldownInitialMinutes = 10
    static let iaCooldownIncrementMinutes = 5
    static let iaBusyMessage = NSLocalizedString("Internet Archive servers are busy.", comment: "")
    static let noNetworkMessage = NSLocalizedString("No network connection.", comment: "")
    static let wifiRequiredMessage = NSLocalizedString("Wi‑Fi connection required.", comment: "")
    static let duplicateHttpStatuses: Set<Int> = [409, 412]

    static func isConnectivityErrorMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        return message == noNetworkMessage || message == wifiRequiredMessage
    }
}
