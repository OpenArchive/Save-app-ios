//
//  UploadErrorAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

class UploadErrorAlert {

    class func present(_ vc: UIViewController, _ upload: Upload) {
        let model = CustomAlertPresentationModel(
            title: NSLocalizedString("Upload Unsuccessful", comment: ""),
            message: NSLocalizedString("Unable to upload due to session error, please try again or contact support", comment: ""),
            primaryButtonTitle: NSLocalizedString("Retry", comment: ""),
            primaryButtonAction: {
                NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
            },
            secondaryButtonTitle: NSLocalizedString("Remove Media", comment: ""),
            secondaryButtonAction: {
                upload.remove()
            },
            secondaryButtonIsOutlined: true,
            showCheckbox: false,
            iconImage: Image(systemName: "exclamationmark.circle")
        )

        CustomAlertPresenter.present(model, from: vc)
    }
}
