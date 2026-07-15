//
//  DispatchGroup+waitSignal.swift
//  Save
//
//  Created by Benjamin Erhart on 09.05.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Foundation

extension DispatchGroup {

    class func enter() -> DispatchGroup {
        let group = DispatchGroup()
        group.enter()

        return group
    }

    @discardableResult
    func wait(signal: Progress) -> DispatchTimeoutResult {
        var result: DispatchTimeoutResult

        repeat {
            result = wait(timeout: .now() + 0.2)
        }
        while result != .success && !signal.isCancelled

        return result
    }

    @discardableResult
    func wait(timeout maxWait: TimeInterval, signal: Progress) -> DispatchTimeoutResult {
        let start = Date()
        var result: DispatchTimeoutResult

        repeat {
            // Poll every 0.2s until cancelled, success, or timeout
            result = wait(timeout: .now() + 0.2)

            // Exit if cancelled or completed
            if signal.isCancelled {
                return .success  // Treat cancellation as completion
            }
            if result == .success {
                return .success
            }

            // Check if we've exceeded the maximum wait time
            if Date().timeIntervalSince(start) >= maxWait {
                return .timedOut
            }
        }
        while result != .success && !signal.isCancelled

        return result
    }
}
