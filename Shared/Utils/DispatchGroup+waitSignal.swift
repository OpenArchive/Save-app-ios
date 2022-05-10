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

//        result = wait(timeout: .now() + 2)
        repeat {
            result = wait(timeout: .now() + 0.2)
        }
        while result != .success && !signal.isCancelled

        return result
    }
}
