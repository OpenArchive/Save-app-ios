//
//  InfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.08.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

/**
 A special alert which gives the user a hint about a special feature.

 New alerts should use `CustomAlertPresenter` / `CustomAlertPresentationModel` directly.
 */
class InfoAlert {

    /**
     An illustrative image shown above the title, if not nil.
    */
    class var image: UIImage? {
        nil
    }

    /**
     A SwiftUI Image for the icon. Override this in subclasses.
    */
    class var iconImage: Image? {
        if let uiImage = image {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "info.circle.fill")
    }

    /**
     The color with which the illustrative image gets tinted.
    */
    class var tintColor: Color {
        .accentColor
    }

    /**
     A title for the alert. Defaults to empty and will not be shown, if left as such.
    */
    class var title: String {
        ""
    }

    /**
     The main message to display.
    */
    class var message: String {
        ""
    }

    /**
     The title of the ok button. Will default to "Got it", if not overridden.
     */
    class var buttonTitle: String {
        NSLocalizedString("Got it", comment: "")
    }

    /**
     Shall be true, if InfoAlert was already shown once and shouldn't be shown
     again.

     Will be set to true after the alert completed.
    */
    class var wasAlreadyShown: Bool {
        get {
            true
        }
        set {
            // Only implemented in subclass.
        }
    }

    /**
     Shows the special info alert, if never shown before.

     - parameter viewController: The viewController to present on. Can be nil,
        in which case the top view controller will be taken.
     - parameter additionalCondition: Only if this condition is *also* met, will this alert be shown. Defaults to `true`.
    */
    class func presentIfNeeded(_ viewController: UIViewController? = nil, additionalCondition: Bool = true, success: (() -> Void)? = nil) {
        if !additionalCondition || wasAlreadyShown {
            success?()

            return
        }

        let model = CustomAlertPresentationModel(
            title: title,
            message: message,
            primaryButtonTitle: buttonTitle,
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle: success != nil ? NSLocalizedString("Cancel", comment: "") : nil,
            secondaryButtonAction: success != nil ? {} : nil,
            showCheckbox: false,
            iconImage: iconImage ?? Image(systemName: "info.circle.fill"),
            iconTint: tintColor
        )

        CustomAlertPresenter.present(model, from: viewController)
    }
}
