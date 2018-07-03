//
//  AlertUtils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

public class AlertUtils {

    /**
     Creates and immediately presents a simple `UIAlertController`.
     It will have one action of type `.cancel` labeled "Cancel".
     Alert style is `.alert`, presentation will be animated.

     - parameter controller: The `UIViewController` to present on.
     - parameter title: The alert title.
     - parameter message: The alert message.
    */
    public class func presentSimple(_ controller: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))

        controller.present(alert, animated: true)
    }

}
