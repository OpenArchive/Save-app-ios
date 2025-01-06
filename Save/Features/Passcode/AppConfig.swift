//
//  AppConfig.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

struct AppConfig {
    
    let passcodeLength: Int
    let maxFailedAttempts: Int
    let maxRetryLimitEnabled: Bool
    let lockoutDuration: TimeInterval // in seconds
    
    static let `default` = AppConfig(
        passcodeLength: 6,
        maxFailedAttempts: 5,
        maxRetryLimitEnabled: true,
        lockoutDuration: 300 // 5 minutes
    )
}
