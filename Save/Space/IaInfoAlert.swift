//
//  IaInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.08.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the Internet Archive support.
 */
class IaInfoAlert: InfoAlert {

    override class var image: UIImage? {
        UIImage(named: "InternetArchiveLogo")
    }

    override class var title: String {
        IaSpace.defaultPrettyName
    }

    override class var message: String {
        String(format: NSLocalizedString(
            "You will need to log in to or create an Internet Archive account in order to send and preserve %@ media at the Internet Archive.",
            comment: ""), Bundle.main.displayName)
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.iaShownFirstTime
        }
        set {
            Settings.iaShownFirstTime = newValue
        }
    }
}
