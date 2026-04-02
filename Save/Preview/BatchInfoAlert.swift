//
//  BatchInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 09.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

/**
 A special alert which informs the user about the batch edit feature.
 */
class BatchInfoAlert {

    static var image: Image? {
        Image("add_media")
    }

    static var title: String {
        NSLocalizedString("Edit Multiple", comment: "")
    }

    static var message: String {
        NSLocalizedString("Press and hold to select and edit multiple media items.", comment: "")
    }

    static var wasAlreadyShown: Bool {
        get {
            Settings.firstBatchEditDone
        }
        set {
            Settings.firstBatchEditDone = newValue
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
            primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle: nil,
            secondaryButtonAction: nil,
            showCheckbox: false,
            iconImage: image ?? Image(systemName: "exclamationmark.triangle.fill")
        )

        CustomAlertPresenter.present(model, from: viewController)
    }
}
