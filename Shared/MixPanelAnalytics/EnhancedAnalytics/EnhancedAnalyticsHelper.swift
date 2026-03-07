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

        showTesterEmailDialog(from: viewController, onIdentified: onIdentified, onSkipped: onSkipped)
    }

    private func showTesterEmailDialog(
        from vc: UIViewController,
        onIdentified: ((String) -> Void)?,
        onSkipped: (() -> Void)?
    ) {
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
