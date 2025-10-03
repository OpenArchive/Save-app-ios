//
//  ratingPopup.swift
//  Save
//
//  Created by navoda on 2025-06-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import StoreKit
import UIKit

func maybePromptForReview() {
    Settings.appLaunchCount += 1
    
    let daysSinceLastPrompt: TimeInterval
    if let lastPromptDate = Settings.lastReviewPromptDate {
        daysSinceLastPrompt = Date().timeIntervalSince(lastPromptDate) / 86400
    } else {
        daysSinceLastPrompt = .infinity // Never prompted before
    }
    
    if Settings.appLaunchCount >= 5 && daysSinceLastPrompt >= 90 {
     
        Settings.lastReviewPromptDate = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
