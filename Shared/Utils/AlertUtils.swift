//
//  AlertUtils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class AlertUtils {

    /**
     Creates and immediately presents a simple `UIAlertController`.
     It will have one action of type `.cancel` labeled "Cancel".
     Alert style is `.alert`, presentation will be animated.

     - parameter controller: The `UIViewController` to present on.
     - parameter title: The alert title.
     - parameter message: The alert message.
    */
    class func presentSimple(_ controller: UIViewController, title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(AlertUtils.getCancelAction())

        controller.present(alert, animated: true)
    }
    
    /**
     - returns: A `UIAlertAction` which can be used to cancel an alert.
    */
    class func getCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
    }
}
