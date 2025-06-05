//
//  ratingPopup.swift
//  Save
//
//  Created by navoda on 2025-06-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import StoreKit

func maybePromptForReview() {

    Settings.appLaunchCount += 1
    
    if Settings.appLaunchCount >= 1 && !Settings.hasPromptedReview {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            SKStoreReviewController.requestReview()
            Settings.hasPromptedReview = true
        }
    }
}
