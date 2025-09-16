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
    
    if Settings.appLaunchCount >= 5 && !Settings.hasPromptedReview {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
            Settings.hasPromptedReview = true
        }
    }
}
