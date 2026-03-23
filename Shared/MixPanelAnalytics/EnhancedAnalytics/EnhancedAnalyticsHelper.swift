//
//  EnhancedAnalyticsHelper.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import UIKit

private let kTesterEmail = "tester_email"
private let userDefaultsSuite = "staging_analytics"

final class EnhancedAnalyticsHelper {

    static let shared = EnhancedAnalyticsHelper()
    
    /// Tracks whether the dialog has been shown during the current app session
    private var hasShownDialogThisSession = false

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: userDefaultsSuite)
    }

    func setupUserIdentification(
        from viewController: UIViewController,
        onIdentified: ((String) -> Void)? = nil,
        onSkipped: (() -> Void)? = nil
    ) {
        guard EnhancedAnalyticsConfig.isEnabled else { return }
        guard let defaults = defaults else { return }

        if let email = defaults.string(forKey: kTesterEmail), !email.isEmpty {
            AnalyticsManager.shared.identifyUser(email: email)
            onIdentified?(email)
            return
        }

        // Only show the dialog once per app session
        guard !hasShownDialogThisSession else { return }
        
        showTesterEmailDialog(from: viewController, onIdentified: onIdentified, onSkipped: onSkipped)
    }

    private func showTesterEmailDialog(
        from vc: UIViewController,
        onIdentified: ((String) -> Void)?,
        onSkipped: (() -> Void)?
    ) {
        hasShownDialogThisSession = true
        
        let alertVC = TesterEmailAlertViewController(
            onContinue: { [weak self] email in
                self?.persistAndIdentify(email: email)
                onIdentified?(email)
            },
            onSkip: {
                onSkipped?()
            }
        )
        vc.present(alertVC, animated: true)
    }

    private func persistAndIdentify(email: String) {
        defaults?.set(email, forKey: kTesterEmail)
        AnalyticsManager.shared.identifyUser(email: email)
    }
}
