//
//  UploadInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 13.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the finality of an upload.
 */
import UIKit
import SwiftUI

class UploadInfoAlert {
    
    static var image: Image? {
        Image(systemName: "exclamationmark.triangle.fill")
    }
    
    static var title: String {
        NSLocalizedString("Warning", comment: "")
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
        
        let alertVC = CustomAlertViewController(
            title: title,
            message: message,
            primaryButtonTitle: NSLocalizedString("Proceed to upload", comment: ""),
            primaryButtonAction: {
                wasAlreadyShown = true
                success?()
            },
            secondaryButtonTitle: NSLocalizedString("Actually, let me edit", comment: ""),
            secondaryButtonAction: nil,
            showCheckbox: true,
            iconImage: image ?? Image(systemName: "exclamationmark.triangle.fill")
        )
        
        if let vc = viewController {
            vc.present(alertVC, animated: true)
        } else {
            UIApplication.shared.windows.first?.rootViewController?.present(alertVC, animated: true)
        }
    }
}

