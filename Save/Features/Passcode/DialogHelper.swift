//
//  DialogHelper.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class DialogHelper {
    
    // MARK: - UIAlertController for UIKit
    
    static func showConfirmationAlert(
        title: String,
        message: String,
        confirmButtonTitle: String = NSLocalizedString("OK",comment: "ok"),
        cancelButtonTitle: String = NSLocalizedString("Cancel",comment: "cancel"),
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        from viewController: UIViewController
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: cancelButtonTitle, style: .cancel, handler: { _ in
            onCancel?()
        }))
        
        alert.addAction(UIAlertAction(title: confirmButtonTitle, style: .destructive, handler: { _ in
            onConfirm()
        }))
        
        viewController.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - SwiftUI Alert
    
    static func createConfirmationAlert(
        title: String,
        message: String,
        confirmButtonTitle: String = NSLocalizedString("OK",comment: "ok"),
        cancelButtonTitle: String = NSLocalizedString("Cancel",comment: "cancel"),
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> Alert {
        Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: .destructive(Text(confirmButtonTitle), action: onConfirm),
            secondaryButton: .cancel(Text(cancelButtonTitle), action: onCancel)
        )
    }
}
