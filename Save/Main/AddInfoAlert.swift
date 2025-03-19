//
//  AddInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the add feature.
 */
import UIKit
import SwiftUI

class AddInfoAlert {
    
    static var image: Image? {
        Image("add_media") // Replace with correct asset name if needed
    }
    
    static var title: String {
        NSLocalizedString("Add Other Media", comment: "")
    }
    
    static var message: String {
        String(format: NSLocalizedString(
            "Press and hold the %@ button to select other files than photos and movies.",
            comment: "placeholder is '+'"), "+")
    }
    
    static var wasAlreadyShown: Bool {
        get {
            Settings.firstAddDone
        }
        set {
            Settings.firstAddDone = newValue
        }
    }
    
    static func presentIfNeeded(viewController: UIViewController? = nil, additionalCondition: Bool = true, success: (() -> Void)? = nil) {
        guard additionalCondition, !wasAlreadyShown else {
            success?()
            return
        }

        let alertVC = CustomAlertViewController(
            title: title,
            message: message,
            primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle:nil,
            secondaryButtonAction: nil,
            showCheckbox: false,
            iconImage: image ?? Image(systemName: "plus.circle.fill") // Use fallback system icon
        )

        if let vc = viewController {
            vc.present(alertVC, animated: true)
        } else {
            UIApplication.shared.windows.first?.rootViewController?.present(alertVC, animated: true)
        }
    }
}
