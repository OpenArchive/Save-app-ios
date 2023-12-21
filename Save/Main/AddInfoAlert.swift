//
//  AddInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the add feature.
 */
class AddInfoAlert: InfoAlert {

    override class var image: UIImage? {
        .icAdd
    }

    override class var tintColor: UIColor {
        .accent
    }

    override class var title: String {
        NSLocalizedString("Add Other Media", comment: "")
    }

    override class var message: String {
        String(format: NSLocalizedString(
            "Press and hold the %@ button to select other files than photos and movies.",
            comment: "placeholder is '+'"), "+")
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.firstAddDone
        }
        set {
            Settings.firstAddDone = newValue
        }
    }
}
