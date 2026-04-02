//
//  UploadInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 13.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

/**
 A special alert which informs the user about the finality of an upload.
 */
class UploadInfoAlert {

    static var image: Image? {
        Image(systemName: "exclamationmark.triangle.fill")
    }

    static var title: String {
        NSLocalizedString("Warning!", comment: "")
    }

    static var message: String {
        NSLocalizedString("Once uploaded, you will not be able to edit media.", comment: "")
    }

    static var wasAlreadyShown: Bool {
        get {
            Settings.firstUploadDone
        }
        set {
            Settings.firstUploadDone = newValue
        }
    }

    static func presentIfNeeded(viewController: UIViewController? = nil, additionalCondition: Bool = true, success: (() -> Void)? = nil) {
        guard additionalCondition, !wasAlreadyShown else {
            success?()
            return
        }

        let model = CustomAlertPresentationModel(
            title: title,
            message: message,
            primaryButtonTitle: NSLocalizedString("Proceed to upload", comment: ""),
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle: NSLocalizedString("Actually, let me edit", comment: ""),
            secondaryButtonAction: {
                // Dismiss only; do not mark as shown or invoke success upload path.
            },
            secondaryButtonIsOutlined: false,
            showCheckbox: true,
            iconImage: image ?? Image(systemName: "exclamationmark.triangle.fill"),
            iconTint: .accent
        )

        CustomAlertPresenter.present(model, from: viewController)
    }
}
