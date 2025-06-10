//
//  UploadErrorAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftUICore

class UploadErrorAlert {
    
    class func present(_ vc: UIViewController, _ upload: Upload) {
        let alertVC = CustomAlertViewController(
            title: NSLocalizedString("Upload Unsuccessful", comment: ""),
            message: NSLocalizedString("Unable to upload due to session error, please try again or contact support", comment: ""),
            primaryButtonTitle: NSLocalizedString("Retry", comment: ""),
            primaryButtonAction: {
                NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
            },
            secondaryButtonTitle: NSLocalizedString("Remove Media", comment: ""),
            secondaryButtonAction: {
                upload.remove()
            }, showCheckbox: false, secondaryButtonIsOutlined: true,
            iconImage: Image(systemName: "exclamationmark.circle")
        )
        
        vc.present(alertVC, animated: true)
    }
}
