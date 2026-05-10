//
//  AddInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

/**
 A special alert which informs the user about the add feature.
 */
class AddInfoAlert {

    static var image: Image? {
        Image("add_media")
    }

    static var title: String {
        NSLocalizedString("Add Media", comment: "")
    }

    static var message: String {
        String(format: NSLocalizedString(
            "Tap %@ to pick from image gallery or press and hold to add media from other apps.",
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

        let model = CustomAlertPresentationModel(
            title: title,
            message: message,
            primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle: nil,
            secondaryButtonAction: nil,
            showCheckbox: false,
            iconImage: image ?? Image(systemName: "plus.circle.fill")
        )

        CustomAlertPresenter.present(model, from: viewController)
    }
}
